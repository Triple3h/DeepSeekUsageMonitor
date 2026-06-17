import AppKit
import DeepSeekUsageMonitorCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    var onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            if model.isAnyBalanceWarning {
                WarningBanner(threshold: model.balanceWarningThreshold)
            }
            HeaderView()
            SectionCard {
                BalanceCardView()
            }
            SectionCard {
                UsageSectionView(
                    displayUsage: displayUsage,
                    displayCost: displayCost,
                    chartDays: chartDays,
                    chartModelNames: chartModelNames,
                    modelColor: modelColor,
                    modelBadge: modelBadge,
                    modelShortName: modelShortName,
                    costForModel: cost(for:),
                    compactNumber: compactNumber,
                    money: money
                )
            }

            // 平台切换器（底部）
            if model.deepSeekEnabled && model.mimoEnabled {
                platformPicker
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background {
            Theme.panelBackground(for: colorScheme)
        }
        .task {
            if model.userSummary == nil && model.usageAmount == nil {
                await model.refreshAll()
            }
        }
    }

    // MARK: - Data Computation

    private var displayUsage: UsageDisplay {
        // DeepSeek 平台数据
        let deepSeekUsage: UsageDisplay = computeDeepSeekUsage()

        // Mimo 平台数据
        let mimoUsage: UsageDisplay = computeMimoUsage()

        // 根据平台选择合并数据
        switch model.selectedPlatform {
        case .all:
            return mergeUsageDisplay(deepSeekUsage, mimoUsage)
        case .deepSeek:
            return deepSeekUsage
        case .mimo:
            return mimoUsage
        }
    }

    private func computeDeepSeekUsage() -> UsageDisplay {
        if model.selectedPeriod == .last7Days {
            let days = last7DaysAmountDays
            let mergedModels = mergeDayModels(days)
            return UsageDisplay(models: mergedModels)
        }

        guard let report = model.usageAmount else {
            return UsageDisplay.empty
        }

        if model.selectedPeriod == .month {
            return UsageDisplay(models: report.models)
        }

        if let today = report.days.first(where: { $0.date == displayUsageDate }) {
            return UsageDisplay(models: today.models)
        }
        if let latestActiveDay = report.days.last(where: { $0.totalTokens > 0 || $0.requestCount > 0 }) {
            return UsageDisplay(models: latestActiveDay.models)
        }
        return UsageDisplay(models: [])
    }

    private func computeMimoUsage() -> UsageDisplay {
        let dates = mimoFilterDates

        if model.mimoBillingMode == .payAsYouGo {
            guard let report = model.mimoUsageDetailReport else { return .empty }
            return UsageDisplay(models: report.asUsageModelAmounts(filteringDates: dates))
        } else {
            guard let report = model.mimoTokenPlanDetailReport else { return .empty }
            return UsageDisplay(models: report.asUsageModelAmounts(filteringDates: dates))
        }
    }

    /// 根据 selectedPeriod 返回需要过滤的日期集合，nil 表示不限（整月）。
    private var mimoFilterDates: Set<String>? {
        switch model.selectedPeriod {
        case .today:
            return Set([displayUsageDate])
        case .last7Days:
            return Set(model.last7DaysDateStrings())
        case .month:
            return nil
        }
    }

    private func mergeUsageDisplay(_ a: UsageDisplay, _ b: UsageDisplay) -> UsageDisplay {
        let mergedModels = (a.models + b.models).reduce(into: [String: [String: Int]]()) { result, model in
            var usage = result[model.model] ?? [:]
            for (type, amount) in model.usage {
                usage[type, default: 0] += amount
            }
            result[model.model] = usage
        }
        return UsageDisplay(models: mergedModels.map { UsageModelAmount(model: $0.key, usage: $0.value) })
    }

    private var displayCost: Decimal? {
        switch model.selectedPlatform {
        case .all:
            return (deepSeekDisplayCost ?? 0) + (mimoDisplayCost ?? 0)
        case .deepSeek:
            return deepSeekDisplayCost
        case .mimo:
            return mimoDisplayCost
        }
    }

    private var deepSeekDisplayCost: Decimal? {
        if model.selectedPeriod == .month {
            return model.usageCost?.totalCost
        }
        if model.selectedPeriod == .last7Days {
            return last7DaysCostDays.reduce(0) { $0 + $1.totalCost }
        }
        return todayCost
    }

    private var mimoDisplayCost: Decimal? {
        if model.mimoBillingMode == .payAsYouGo {
            guard let report = model.mimoUsageDetailReport else { return nil }

            if model.selectedPeriod == .month {
                return report.totalCost
            }

            if model.selectedPeriod == .last7Days {
                let targetDates = Set(model.last7DaysDateStrings())
                return report.details.filter { targetDates.contains($0.date) }.reduce(0) { $0 + $1.consumedAmountDecimal }
            }

            // 今日
            return report.details.filter { $0.date == displayUsageDate }.reduce(0) { $0 + $1.consumedAmountDecimal }
        } else {
            // Token Plan 模式不显示费用
            return nil
        }
    }

    private var todayCost: Decimal? {
        cost(for: todayDateString())
    }

    private var displayUsageDate: String {
        let targetDate = todayDateString()
        guard model.selectedPeriod == .today, let report = model.usageAmount else {
            return targetDate
        }
        if report.days.contains(where: { $0.date == targetDate }) {
            return targetDate
        }
        return report.days.last(where: { $0.totalTokens > 0 || $0.requestCount > 0 })?.date ?? targetDate
    }

    // MARK: - Chart Data

    private var chartDays: [UsageDayAmount] {
        let sourceDays: [UsageDayAmount]

        switch model.selectedPlatform {
        case .all:
            sourceDays = mergedChartDays(deepSeekChartDays() + mimoChartDays())
        case .deepSeek:
            sourceDays = deepSeekChartDays()
        case .mimo:
            sourceDays = mimoChartDays()
        }

        return chartDaysForSelectedPeriod(sourceDays)
    }

    private func chartDaysForSelectedPeriod(_ days: [UsageDayAmount]) -> [UsageDayAmount] {
        if model.selectedPeriod == .last7Days {
            let targetDates = Set(model.last7DaysDateStrings())
            return days.filter { targetDates.contains($0.date) }
        }
        return Array(days.suffix(7))
    }

    private func deepSeekChartDays() -> [UsageDayAmount] {
        if model.selectedPeriod == .last7Days {
            let targetDates = model.last7DaysDateStrings()
            let allDays = (model.usageAmount?.days ?? []) + (model.previousMonthUsageAmount?.days ?? [])
            let dayMap = Dictionary(uniqueKeysWithValues: allDays.map { ($0.date, $0) })
            return targetDates.map { date in
                dayMap[date] ?? UsageDayAmount(date: date, models: [])
            }
        }

        guard let report = model.usageAmount else {
            return (0..<7).map { UsageDayAmount(date: "D\($0 + 1)", models: []) }
        }

        let active = report.days.filter { $0.totalTokens > 0 }
        return Array((active.isEmpty ? report.days : active).suffix(7))
    }

    private func mimoChartDays() -> [UsageDayAmount] {
        let report: [UsageDayAmount]
        if model.mimoBillingMode == .payAsYouGo {
            report = model.mimoUsageDetailReport?.asUsageDayAmounts() ?? []
        } else {
            report = model.mimoTokenPlanDetailReport?.asUsageDayAmounts() ?? []
        }

        guard !report.isEmpty else { return report }

        if model.selectedPeriod == .last7Days {
            return report.sorted { $0.date < $1.date }
        }

        return Array(report.sorted { $0.date < $1.date }.suffix(7))
    }

    private func mergedChartDays(_ days: [UsageDayAmount]) -> [UsageDayAmount] {
        var merged: [String: [UsageModelAmount]] = [:]
        var dateOrder: [String] = []
        for day in days {
            if merged[day.date] == nil { dateOrder.append(day.date) }
            merged[day.date, default: []].append(contentsOf: day.models)
        }

        return dateOrder.sorted().map { date in
            let models = merged[date] ?? []
            return UsageDayAmount(
                date: date,
                models: models.filter { $0.totalTokens > 0 || $0.requestCount > 0 }
            )
        }
    }

    private var chartModelNames: [String] {
        let totals = chartDays
            .flatMap(\.models)
            .filter { $0.totalTokens > 0 }
            .reduce(into: [String: Int]()) { result, item in
                result[item.model, default: 0] += item.totalTokens
            }

        return totals
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
                }
                return lhs.value > rhs.value
            }
            .map(\.key)
    }

    // MARK: - Helper Methods

    private func cost(for item: UsageModelAmount) -> Decimal? {
        // DeepSeek 部分
        let deepSeekCost: Decimal?
        switch model.selectedPeriod {
        case .month:
            deepSeekCost = model.usageCost?.models.first(where: { $0.model == item.model })?.totalCost
        case .last7Days:
            let costModels = mergeCostDayModels(last7DaysCostDays)
            deepSeekCost = costModels.first(where: { $0.model == item.model })?.totalCost
        case .today:
            let costModels = model.usageCost?.days.first(where: { $0.date == displayUsageDate })?.models ?? []
            deepSeekCost = costModels.first(where: { $0.model == item.model })?.totalCost
        }

        // Mimo 部分（仅按量计费有 cost）
        let mimoCost: Decimal? = mimoCostForModel(item)

        // 合并
        let ds = deepSeekCost ?? 0
        let mm = mimoCost ?? 0
        let sum = ds + mm
        return sum > 0 ? sum : nil
    }

    private func cost(for date: String) -> Decimal? {
        // DeepSeek 部分
        let deepSeekCost: Decimal?
        if model.selectedPeriod == .last7Days {
            let allDays = (model.usageCost?.days ?? []) + (model.previousMonthUsageCost?.days ?? [])
            deepSeekCost = allDays.first(where: { $0.date == date })?.totalCost
        } else {
            deepSeekCost = model.usageCost?.days.first(where: { $0.date == date })?.totalCost
        }

        // Mimo 部分（仅按量计费有 cost）
        let mimoCost: Decimal? = mimoCostForDate(date)

        let ds = deepSeekCost ?? 0
        let mm = mimoCost ?? 0
        let sum = ds + mm
        return sum > 0 ? sum : nil
    }

    /// Mimo 按量计费：查询某个模型的总花费。
    private func mimoCostForModel(_ item: UsageModelAmount) -> Decimal? {
        guard model.mimoBillingMode == .payAsYouGo,
              let report = model.mimoUsageDetailReport else { return nil }
        let dates = mimoFilterDates
        return report.costForModel(item, filteringDates: dates)
    }

    /// Mimo 按量计费：查询某天的总花费。
    private func mimoCostForDate(_ date: String) -> Decimal? {
        guard model.mimoBillingMode == .payAsYouGo,
              let report = model.mimoUsageDetailReport else { return nil }
        return report.details
            .filter { $0.date == date }
            .reduce(Decimal.zero) { $0 + $1.consumedAmountDecimal }
    }

    private var last7DaysCostDays: [UsageCostDayAmount] {
        let targetDates = Set(model.last7DaysDateStrings())
        let allDays = (model.usageCost?.days ?? []) + (model.previousMonthUsageCost?.days ?? [])
        return allDays.filter { targetDates.contains($0.date) }.sorted { $0.date < $1.date }
    }

    private var last7DaysAmountDays: [UsageDayAmount] {
        let targetDates = Set(model.last7DaysDateStrings())
        let allDays = (model.usageAmount?.days ?? []) + (model.previousMonthUsageAmount?.days ?? [])
        return allDays.filter { targetDates.contains($0.date) }.sorted { $0.date < $1.date }
    }

    private func mergeDayModels(_ days: [UsageDayAmount]) -> [UsageModelAmount] {
        var merged: [String: [String: Int]] = [:]
        for day in days {
            for model in day.models {
                var usage = merged[model.model] ?? [:]
                for (type, amount) in model.usage {
                    usage[type, default: 0] += amount
                }
                merged[model.model] = usage
            }
        }
        return merged.map { UsageModelAmount(model: $0.key, usage: $0.value) }
    }

    private func mergeCostDayModels(_ days: [UsageCostDayAmount]) -> [UsageCostModelAmount] {
        var merged: [String: [String: Decimal]] = [:]
        for day in days {
            for model in day.models {
                var usage = merged[model.model] ?? [:]
                for (type, amount) in model.usage {
                    usage[type, default: 0] += amount
                }
                merged[model.model] = usage
            }
        }
        return merged.map { UsageCostModelAmount(model: $0.key, usage: $0.value) }
    }

    // MARK: - Formatting

    private func modelColor(_ modelName: String?, fallbackIndex: Int) -> Color {
        let lower = modelName?.lowercased() ?? ""
        let isMimoModel = lower.contains("mimo")

        if isMimoModel {
            return mimoModelColor(lower)
        } else {
            return deepSeekModelColor(lower)
        }
    }

    /// DeepSeek 模型：蓝色系，Pro 深、Flash 浅
    private func deepSeekModelColor(_ lower: String) -> Color {
        if lower.contains("pro") {
            return Color(red: 0.20, green: 0.30, blue: 0.85)  // 深蓝
        } else if lower.contains("flash") {
            return Color(red: 0.45, green: 0.62, blue: 1.00)  // 浅蓝
        } else if lower.contains("reasoner") || lower.contains("r1") {
            return Color(red: 0.22, green: 0.48, blue: 0.90)  // 青蓝
        } else if lower.contains("v4") {
            return Color(red: 0.30, green: 0.42, blue: 0.99)  // 品牌蓝
        } else if lower.contains("v3") || lower.contains("chat") {
            return Color(red: 0.35, green: 0.55, blue: 0.96)  // 天蓝
        }
        return Color(red: 0.30, green: 0.42, blue: 0.99)    // 默认蓝
    }

    /// Mimo 模型：橙色系，Pro 深、标准 浅
    private func mimoModelColor(_ lower: String) -> Color {
        if lower.contains("pro") {
            return Color(red: 0.85, green: 0.32, blue: 0.12)  // 深橙
        } else if lower.contains("v2.5") || lower.contains("v2") {
            return Color(red: 1.00, green: 0.50, blue: 0.22)  // 标准橙
        }
        return Color(red: 1.00, green: 0.42, blue: 0.21)    // 默认橙
    }

    private func modelBadge(_ modelName: String, index: Int) -> String {
        let lower = modelName.lowercased()

        // DeepSeek 模型徽章（限制在 2-3 个字符）
        if lower.contains("deepseek") {
            if lower.contains("v4-flash") { return "FL" }
            if lower.contains("v4-pro") { return "PR" }
            if lower.contains("flash") { return "FL" }
            if lower.contains("v4") { return "V4" }
            if lower.contains("reasoner") || lower.contains("r1") { return "R1" }
            if lower.contains("chat") || lower.contains("v3") { return "V3" }
            return "DS"
        }

        // Mimo 模型徽章（限制在 2-3 个字符）
        if lower.contains("mimo") {
            if lower.contains("v2.5-pro") { return "MP" }
            if lower.contains("v2.5") { return "M2" }
            if lower.contains("pro") { return "PR" }
            if lower.contains("v2") { return "V2" }
            return "M"
        }

        // 其他模型
        return "M\(index + 1)"
    }

    /// 模型对应的 SF Symbol 图标名，nil 表示使用纯文字徽章
    private func modelBadgeSymbol(_ modelName: String) -> String? {
        let lower = modelName.lowercased()
        if lower.contains("flash") { return "bolt.fill" }
        if lower.contains("pro") { return "star.fill" }
        if lower.contains("reasoner") || lower.contains("r1") { return "sparkles" }
        if lower.contains("mimo") { return "flame.fill" }
        return nil
    }

    private func modelShortName(_ modelName: String) -> String {
        modelBadge(modelName, index: 0)
    }

    private func compactNumber(_ value: Int) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.1fB", Double(value) / 1_000_000_000)
        }
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return value.formatted()
    }

    private func money(_ value: Decimal?, currency: String?) -> String {
        guard let value else { return "--" }
        let symbol = currency?.uppercased() == "CNY" || currency == nil ? "¥" : "\(currency ?? "") "
        let number = NSDecimalNumber(decimal: value).doubleValue
        return "\(symbol)\(String(format: "%.2f", number))"
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Platform Picker

    private var platformPicker: some View {
        HStack(spacing: 0) {
            ForEach(AppModel.Platform.allCases, id: \.self) { platform in
                Button {
                    model.selectedPlatform = platform
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(platformColor(platform))
                            .frame(width: 6, height: 6)
                        Text(platform.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        model.selectedPlatform == platform
                            ? RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.09))
                            : nil
                    )
                    .foregroundStyle(model.selectedPlatform == platform ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func platformColor(_ platform: AppModel.Platform) -> Color {
        switch platform {
        case .all:
            return Color(red: 0.30, green: 0.42, blue: 0.99)
        case .deepSeek:
            return Color(red: 0.30, green: 0.42, blue: 0.99)
        case .mimo:
            return Color(red: 1.00, green: 0.42, blue: 0.21)
        }
    }
}

// MARK: - UsageDisplay

struct UsageDisplay {
    static let empty = UsageDisplay(models: [])

    let models: [UsageModelAmount]

    init(models: [UsageModelAmount]) {
        self.models = models.filter { $0.totalTokens > 0 }
    }

    var requestCount: Int { models.reduce(0) { $0 + $1.requestCount } }
    var inputTokens: Int { models.reduce(0) { $0 + $1.inputTokens } }
    var responseTokens: Int { models.reduce(0) { $0 + $1.responseTokens } }
    var totalTokens: Int { inputTokens + responseTokens }
}
