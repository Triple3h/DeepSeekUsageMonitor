import Combine
import DeepSeekUsageMonitorCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    // DeepSeek 平台
    @Published var platformBearerDraft = ""
    @Published var balanceWarningThresholdDraft = "10"
    @Published var autoRefreshMinutesDraft = "5"
    @Published var launchAtLoginEnabled = false
    @Published var usageAmount: UsageAmountReport?
    @Published var usageCost: UsageCostReport?
    @Published var previousMonthUsageAmount: UsageAmountReport?
    @Published var previousMonthUsageCost: UsageCostReport?
    @Published var userSummary: UserSummaryReport?
    @Published var deepSeekEnabled = true

    // Mimo 平台
    @Published var mimoCookieDraft = ""
    @Published var mimoBillingMode: MimoBillingMode = .payAsYouGo
    @Published var mimoEnabled = false
    @Published var mimoUsageOverview: MimoUsageOverview?
    @Published var mimoUsageDetailReport: MimoUsageDetailReport?
    @Published var mimoTokenPlanUsage: MimoTokenPlanUsage?
    @Published var mimoTokenPlanDetailReport: MimoTokenPlanDetailReport?
    @Published var mimoBalance: MimoBalanceReport?

    // 通用状态
    @Published var selectedPeriod: UsagePeriod = .today
    @Published var selectedMonth: Int
    @Published var selectedYear: Int
    @Published var selectedPlatform: Platform = .all
    /// 面板是否显示设置页面
    @Published var isSettingsShown = false
    /// 主题模式
    @Published var selectedTheme: AppThemeMode = .system

    @Published var isRefreshingBalance = false
    @Published var isRefreshingUsage = false
    @Published var statusMessage = "未刷新"
    @Published var errorMessage: String?

    private let keychain = KeychainStore()
    private let platformClient = PlatformSummaryClient()
    private let mimoClient = MimoClient()
    private let cacheStore = UsageCacheStore()
    private var backgroundRefreshTask: Task<Void, Never>?

    // 缓存已保存的 credential，避免每次刷新都访问 Keychain
    private var savedBearerToken: String = ""
    private var savedMimoCookie: String = ""

    init() {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        selectedMonth = components.month ?? 1
        selectedYear = components.year ?? 2026
        loadSavedCredentials()
        startBackgroundRefresh()
    }

    // 平台枚举
    enum Platform: String, CaseIterable {
        case all = "全部"
        case deepSeek = "DeepSeek"
        case mimo = "Mimo"
    }

    var balanceWarningThreshold: Double {
        Double(balanceWarningThresholdDraft) ?? 10
    }

    var selectedMonthTitle: String {
        String(format: "%04d年%02d月", selectedYear, selectedMonth)
    }

    var canMoveToNextMonth: Bool {
        let current = Calendar.current.dateComponents([.year, .month], from: Date())
        guard let currentYear = current.year, let currentMonth = current.month else {
            return true
        }
        return selectedYear < currentYear || (selectedYear == currentYear && selectedMonth < currentMonth)
    }

    var totalBalanceValue: Double? {
        userSummary?.totalBalance.doubleValue
    }

    var isBalanceWarning: Bool {
        guard let totalBalanceValue else {
            return false
        }
        return totalBalanceValue < balanceWarningThreshold
    }

    var platformCredentialStatus: PlatformCredentialStatus {
        return PlatformCredentialStatus(
            hasBearerToken: savedBearerToken.isEmpty == false
        )
    }

    var mimoCredentialStatus: Bool {
        return savedMimoCookie.isEmpty == false
    }

    /// 各启用平台本月花费之和（只加花费，不混入余额）
    var combinedMonthCost: Double? {
        var cost: Double = 0
        var hasAny = false
        if deepSeekEnabled, let ds = userSummary?.monthlyCost.doubleValue {
            cost += ds; hasAny = true
        }
        if mimoEnabled, let mimo = mimoUsageOverview?.currentMonthCost.doubleValue {
            cost += mimo; hasAny = true
        }
        return hasAny ? cost : nil
    }

    func loadSavedCredentials() {
        do {
            platformBearerDraft = try keychain.read(.platformBearerToken) ?? ""
            mimoCookieDraft = try keychain.read(.mimoCookie) ?? ""

            #if DEBUG
            let env = ProcessInfo.processInfo.environment
            if platformBearerDraft.isEmpty {
                platformBearerDraft = env["DEEPSEEK_BEARER"] ?? ""
            }
            if mimoCookieDraft.isEmpty {
                mimoCookieDraft = env["MIMO_COOKIE"] ?? ""
            }
            #endif

            balanceWarningThresholdDraft = UserDefaults.standard.string(forKey: "balanceWarningThreshold") ?? "10"
            autoRefreshMinutesDraft = UserDefaults.standard.string(forKey: "autoRefreshMinutes") ?? "5"
            launchAtLoginEnabled = LaunchAtLoginManager.isEnabled

            // 加载平台启用状态
            deepSeekEnabled = UserDefaults.standard.bool(forKey: "deepSeekEnabled")
            if !UserDefaults.standard.objectExists(forKey: "deepSeekEnabled") {
                deepSeekEnabled = true // 默认启用
            }

            mimoEnabled = UserDefaults.standard.bool(forKey: "mimoEnabled")
            if !UserDefaults.standard.objectExists(forKey: "mimoEnabled") {
                mimoEnabled = false // 默认不启用
            }

            // 加载 Mimo 计费模式
            if let modeString = UserDefaults.standard.string(forKey: "mimoBillingMode"),
               let mode = MimoBillingMode(rawValue: modeString) {
                mimoBillingMode = mode
            }

            // 加载主题模式
            if let themeString = UserDefaults.standard.string(forKey: "selectedTheme"),
               let theme = AppThemeMode(rawValue: themeString) {
                selectedTheme = theme
            }

            // 缓存已保存的 credential，刷新时直接使用
            savedBearerToken = platformBearerDraft
            savedMimoCookie = mimoCookieDraft
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveSettings() {
        do {
            let previousRefreshMinutes = UserDefaults.standard.string(forKey: "autoRefreshMinutes") ?? "5"
            try keychain.save(platformBearerDraft.trimmingCharacters(in: .whitespacesAndNewlines), account: .platformBearerToken)
            try keychain.save(mimoCookieDraft.trimmingCharacters(in: .whitespacesAndNewlines), account: .mimoCookie)
            UserDefaults.standard.set(balanceWarningThresholdDraft.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "balanceWarningThreshold")
            UserDefaults.standard.set(autoRefreshMinutesDraft.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "autoRefreshMinutes")
            UserDefaults.standard.set(deepSeekEnabled, forKey: "deepSeekEnabled")
            UserDefaults.standard.set(mimoEnabled, forKey: "mimoEnabled")
            UserDefaults.standard.set(mimoBillingMode.rawValue, forKey: "mimoBillingMode")
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")

            // 更新缓存的 credential
            savedBearerToken = platformBearerDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            savedMimoCookie = mimoCookieDraft.trimmingCharacters(in: .whitespacesAndNewlines)

            if previousRefreshMinutes != autoRefreshMinutesDraft {
                startBackgroundRefresh()
            }
            statusMessage = "设置已保存"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            launchAtLoginEnabled = LaunchAtLoginManager.enable()
        } else {
            launchAtLoginEnabled = !LaunchAtLoginManager.disable()
        }
    }

    func startBackgroundRefresh() {
        backgroundRefreshTask?.cancel()
        let minutes = Double(autoRefreshMinutesDraft) ?? 5
        guard minutes > 0 else { return }
        backgroundRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(minutes * 60 * 1_000_000_000))
                if Task.isCancelled { break }
                await self.refreshAll()
            }
        }
    }

    func stopBackgroundRefresh() {
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = nil
    }

    func refreshBalance() async {
        isRefreshingBalance = true
        defer { isRefreshingBalance = false }

        var errors: [String] = []

        // DeepSeek 平台
        if deepSeekEnabled {
            do {
                userSummary = try await platformClient.fetchUserSummary(bearerToken: savedBearerToken)
            } catch {
                errors.append("DeepSeek: \(error.localizedDescription)")
            }
        }

        // Mimo 平台（余额两个模式都需要，按模式决定 fetch 用量/套餐）
        if mimoEnabled {
            // 并行 fetch，各接口独立处理错误
            async let balanceResult = mimoClient.fetchBalance(cookieString: savedMimoCookie)
            if mimoBillingMode == .payAsYouGo {
                async let overviewResult = mimoClient.fetchUsageOverview(cookieString: savedMimoCookie)
                do { mimoUsageOverview = try await overviewResult } catch {
                    errors.append("Mimo 用量: \(error.localizedDescription)")
                }
            } else {
                async let tokenPlanResult = mimoClient.fetchTokenPlanUsage(cookieString: savedMimoCookie)
                do { mimoTokenPlanUsage = try await tokenPlanResult } catch {
                    errors.append("Mimo 套餐: \(error.localizedDescription)")
                }
            }
            do { mimoBalance = try await balanceResult } catch {
                errors.append("Mimo 余额: \(error.localizedDescription)")
            }
        }

        if errors.isEmpty {
            statusMessage = "余额已刷新"
            errorMessage = nil
        } else {
            errorMessage = errors.joined(separator: "\n")
        }
    }

    func refreshPlatformData() async {
        isRefreshingUsage = true
        defer { isRefreshingUsage = false }

        let isCurrent = isCurrentMonth(year: selectedYear, month: selectedMonth)
        let cacheMaxAge: TimeInterval = isCurrent ? 3600 : 604800 // 1 hour for current month, 7 days for history

        var errors: [String] = []

        // DeepSeek 平台
        if deepSeekEnabled {
            // Show cached data immediately if available and not stale
            if usageAmount == nil {
                usageAmount = cacheStore.loadIfValid(UsageAmountReport.self, year: selectedYear, month: selectedMonth, maxAge: cacheMaxAge)
            }
            if usageCost == nil {
                usageCost = cacheStore.loadIfValid(UsageCostReport.self, year: selectedYear, month: selectedMonth, maxAge: cacheMaxAge)
            }

            do {
                async let usage = platformClient.fetchUsageAmount(
                    month: selectedMonth,
                    year: selectedYear,
                    bearerToken: savedBearerToken
                )
                async let cost = platformClient.fetchUsageCost(
                    month: selectedMonth,
                    year: selectedYear,
                    bearerToken: savedBearerToken
                )
                async let summary = platformClient.fetchUserSummary(bearerToken: savedBearerToken)
                let newUsage = try await usage
                let newCost = try await cost
                usageAmount = newUsage
                usageCost = newCost
                userSummary = try await summary
                cacheStore.save(newUsage, year: selectedYear, month: selectedMonth)
                cacheStore.save(newCost, year: selectedYear, month: selectedMonth)
            } catch {
                // If network fails but we have cached data, keep it and show a subtle message
                if usageAmount != nil || usageCost != nil {
                    statusMessage = "已显示缓存数据"
                } else {
                    errors.append("DeepSeek: \(error.localizedDescription)")
                }
            }
        }

        // Mimo 平台（余额两个模式都要，详情按模式决定）
        if mimoEnabled {
            async let balanceResult = mimoClient.fetchBalance(cookieString: savedMimoCookie)
            async let overviewResult = mimoClient.fetchUsageOverview(cookieString: savedMimoCookie)

            do { mimoBalance = try await balanceResult } catch {
                errors.append("Mimo 余额: \(error.localizedDescription)")
            }
            do { mimoUsageOverview = try await overviewResult } catch {
                errors.append("Mimo 概览: \(error.localizedDescription)")
            }

            if mimoBillingMode == .payAsYouGo {
                // 先尝试加载缓存
                if mimoUsageDetailReport == nil {
                    mimoUsageDetailReport = cacheStore.loadIfValid(MimoUsageDetailReport.self, year: selectedYear, month: selectedMonth, maxAge: cacheMaxAge)
                }

                do {
                    let detail = try await mimoClient.fetchUsageDetailList(
                        month: selectedMonth, year: selectedYear, cookieString: savedMimoCookie)
                    mimoUsageDetailReport = detail
                    cacheStore.save(detail, year: selectedYear, month: selectedMonth)
                } catch {
                    // 网络失败时：如果已有缓存数据，显示警告；否则尝试加载任何缓存
                    if mimoUsageDetailReport != nil {
                        errors.append("Mimo 按量详情: \(error.localizedDescription)（已显示缓存数据）")
                    } else if let cached = cacheStore.load(MimoUsageDetailReport.self, year: selectedYear, month: selectedMonth) {
                        mimoUsageDetailReport = cached
                        statusMessage = "已显示缓存数据"
                    } else {
                        errors.append("Mimo 按量详情: \(error.localizedDescription)")
                    }
                }
            } else {
                // Token Plan 模式
                // 先尝试加载缓存
                if mimoTokenPlanDetailReport == nil {
                    mimoTokenPlanDetailReport = cacheStore.loadIfValid(MimoTokenPlanDetailReport.self, year: selectedYear, month: selectedMonth, maxAge: cacheMaxAge)
                }

                async let tpResult = mimoClient.fetchTokenPlanUsage(cookieString: savedMimoCookie)

                do {
                    let detail = try await mimoClient.fetchTokenPlanDetailList(
                        month: selectedMonth, year: selectedYear, cookieString: savedMimoCookie)
                    mimoTokenPlanDetailReport = detail
                    cacheStore.save(detail, year: selectedYear, month: selectedMonth)
                } catch {
                    // 网络失败时：如果已有缓存数据，显示警告；否则尝试加载任何缓存
                    if mimoTokenPlanDetailReport != nil {
                        errors.append("Mimo 套餐详情: \(error.localizedDescription)（已显示缓存数据）")
                    } else if let cached = cacheStore.load(MimoTokenPlanDetailReport.self, year: selectedYear, month: selectedMonth) {
                        mimoTokenPlanDetailReport = cached
                        statusMessage = "已显示缓存数据"
                    } else {
                        errors.append("Mimo 套餐详情: \(error.localizedDescription)")
                    }
                }

                do { mimoTokenPlanUsage = try await tpResult } catch {
                    errors.append("Mimo 套餐概览: \(error.localizedDescription)")
                }
            }
        }

        if errors.isEmpty {
            statusMessage = "用量已刷新"
            errorMessage = nil
        } else {
            errorMessage = errors.joined(separator: "\n")
        }
    }

    func refreshAll() async {
        await refreshPlatformData()
        if selectedPeriod == .last7Days {
            await refreshPreviousMonthDataIfNeeded()
        }
    }

    func refreshPreviousMonthDataIfNeeded() async {
        guard selectedPeriod == .last7Days, last7DaysSpansMonths else { return }
        let (month, year) = previousMonthForLast7Days

        // Try cache first
        previousMonthUsageAmount = cacheStore.loadIfValid(UsageAmountReport.self, year: year, month: month, maxAge: 604800)
        previousMonthUsageCost = cacheStore.loadIfValid(UsageCostReport.self, year: year, month: month, maxAge: 604800)

        // Skip network if cache is fresh
        if previousMonthUsageAmount != nil && previousMonthUsageCost != nil {
            return
        }

        do {
            async let usage = platformClient.fetchUsageAmount(
                month: month,
                year: year,
                bearerToken: savedBearerToken
            )
            async let cost = platformClient.fetchUsageCost(
                month: month,
                year: year,
                bearerToken: savedBearerToken
            )
            let newUsage = try await usage
            let newCost = try await cost
            previousMonthUsageAmount = newUsage
            previousMonthUsageCost = newCost
            cacheStore.save(newUsage, year: year, month: month)
            cacheStore.save(newCost, year: year, month: month)
        } catch {
            // Silently fail; previous month data is best-effort for last-7-days view
        }
    }

    var last7DaysSpansMonths: Bool {
        let calendar = Calendar.current
        let today = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return false }
        let todayMonth = calendar.component(.month, from: today)
        let weekAgoMonth = calendar.component(.month, from: weekAgo)
        return todayMonth != weekAgoMonth
    }

    var previousMonthForLast7Days: (month: Int, year: Int) {
        let calendar = Calendar.current
        let today = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else {
            return (selectedMonth, selectedYear)
        }
        let components = calendar.dateComponents([.year, .month], from: weekAgo)
        return (components.month ?? 1, components.year ?? 2026)
    }

    func last7DaysDateStrings() -> [String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        var dates: [String] = []
        for i in (0...6).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                dates.append(formatter.string(from: date))
            }
        }
        return dates
    }

    private func isCurrentMonth(year: Int, month: Int) -> Bool {
        let current = Calendar.current.dateComponents([.year, .month], from: Date())
        return current.year == year && current.month == month
    }

    func moveToPreviousMonth() {
        if selectedMonth == 1 {
            selectedMonth = 12
            selectedYear -= 1
        } else {
            selectedMonth -= 1
        }
        if selectedPeriod == .today {
            selectedPeriod = .month
        }
    }

    func moveToNextMonth() {
        guard canMoveToNextMonth else {
            return
        }
        if selectedMonth == 12 {
            selectedMonth = 1
            selectedYear += 1
        } else {
            selectedMonth += 1
        }
        if selectedPeriod == .today {
            selectedPeriod = .month
        }
    }
}

enum UsagePeriod: Hashable {
    case today
    case last7Days
    case month
}

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

extension UserDefaults {
    func objectExists(forKey: String) -> Bool {
        return object(forKey: forKey) != nil
    }
}
