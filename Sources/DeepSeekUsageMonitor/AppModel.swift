import Combine
import DeepSeekUsageMonitorCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var platformBearerDraft = ""
    @Published var platformCookieDraft = ""
    @Published var balanceWarningThresholdDraft = "10"
    @Published var autoRefreshMinutesDraft = "5"
    @Published var launchAtLoginEnabled = false
    @Published var usageAmount: UsageAmountReport?
    @Published var usageCost: UsageCostReport?
    @Published var userSummary: UserSummaryReport?
    @Published var selectedPeriod: UsagePeriod = .today
    @Published var selectedMonth: Int
    @Published var selectedYear: Int
    @Published var isRefreshingBalance = false
    @Published var isRefreshingUsage = false
    @Published var statusMessage = "未刷新"
    @Published var errorMessage: String?

    private let keychain = KeychainStore()
    private let platformClient = PlatformSummaryClient()
    private var backgroundRefreshTask: Task<Void, Never>?

    init() {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        selectedMonth = components.month ?? 1
        selectedYear = components.year ?? 2026
        loadSavedCredentials()
        startBackgroundRefresh()
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
        let token = (try? keychain.read(.platformBearerToken)) ?? nil
        let cookie = (try? keychain.read(.platformCookie)) ?? nil
        return PlatformCredentialStatus(
            hasBearerToken: token?.isEmpty == false,
            hasCookie: cookie?.isEmpty == false
        )
    }

    func loadSavedCredentials() {
        do {
            platformBearerDraft = try keychain.read(.platformBearerToken) ?? ""
            platformCookieDraft = try keychain.read(.platformCookie) ?? ""

            #if DEBUG
            let env = ProcessInfo.processInfo.environment
            if platformBearerDraft.isEmpty {
                platformBearerDraft = env["DEEPSEEK_BEARER"] ?? ""
            }
            if platformCookieDraft.isEmpty {
                platformCookieDraft = env["DEEPSEEK_COOKIE"] ?? ""
            }
            #endif

            balanceWarningThresholdDraft = UserDefaults.standard.string(forKey: "balanceWarningThreshold") ?? "10"
            autoRefreshMinutesDraft = UserDefaults.standard.string(forKey: "autoRefreshMinutes") ?? "5"
            launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveSettings() {
        do {
            let previousRefreshMinutes = UserDefaults.standard.string(forKey: "autoRefreshMinutes") ?? "5"
            try keychain.save(platformBearerDraft.trimmingCharacters(in: .whitespacesAndNewlines), account: .platformBearerToken)
            try keychain.save(platformCookieDraft.trimmingCharacters(in: .whitespacesAndNewlines), account: .platformCookie)
            UserDefaults.standard.set(balanceWarningThresholdDraft.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "balanceWarningThreshold")
            UserDefaults.standard.set(autoRefreshMinutesDraft.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "autoRefreshMinutes")
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

    func refreshBalance() async {
        isRefreshingBalance = true
        defer { isRefreshingBalance = false }

        do {
            let bearer = try keychain.read(.platformBearerToken) ?? ""
            let cookie = try keychain.read(.platformCookie)
            userSummary = try await platformClient.fetchUserSummary(bearerToken: bearer, cookie: cookie)
            statusMessage = "余额已刷新"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshPlatformData() async {
        isRefreshingUsage = true
        defer { isRefreshingUsage = false }

        do {
            let bearer = try keychain.read(.platformBearerToken) ?? ""
            let cookie = try keychain.read(.platformCookie)
            async let usage = platformClient.fetchUsageAmount(
                month: selectedMonth,
                year: selectedYear,
                bearerToken: bearer,
                cookie: cookie
            )
            async let cost = platformClient.fetchUsageCost(
                month: selectedMonth,
                year: selectedYear,
                bearerToken: bearer,
                cookie: cookie
            )
            async let summary = platformClient.fetchUserSummary(bearerToken: bearer, cookie: cookie)
            usageAmount = try await usage
            usageCost = try await cost
            userSummary = try await summary
            statusMessage = "用量已刷新"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAll() async {
        await refreshPlatformData()
    }

    func moveToPreviousMonth() {
        if selectedMonth == 1 {
            selectedMonth = 12
            selectedYear -= 1
        } else {
            selectedMonth -= 1
        }
        selectedPeriod = .month
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
        selectedPeriod = .month
    }
}

enum UsagePeriod: Hashable {
    case today
    case month
}

private extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
