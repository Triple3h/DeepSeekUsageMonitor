import AppKit
import DeepSeekUsageMonitorCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    var onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            if model.isBalanceWarning {
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
            FooterView(
                onOpenConsole: {
                    NSWorkspace.shared.open(URL(string: "https://platform.deepseek.com/usage")!)
                },
                onQuit: {
                    NSApplication.shared.terminate(nil)
                }
            )
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .background {
            // 纯色背景，与卡片背景区分
            Color(nsColor: .windowBackgroundColor)
        }
        .task {
            if model.userSummary == nil && model.usageAmount == nil {
                await model.refreshAll()
            }
        }
    }

    // MARK: - Data Computation

    private var displayUsage: UsageDisplay {
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

    private var displayCost: Decimal? {
        if model.selectedPeriod == .month {
            return model.usageCost?.totalCost
        }
        if model.selectedPeriod == .last7Days {
            return last7DaysCostDays.reduce(0) { $0 + $1.totalCost }
        }
        return todayCost
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
        let source = active.isEmpty ? report.days : active
        return Array(source.suffix(7))
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
        let costModels: [UsageCostModelAmount]
        switch model.selectedPeriod {
        case .month:
            costModels = model.usageCost?.models ?? []
        case .last7Days:
            costModels = mergeCostDayModels(last7DaysCostDays)
        case .today:
            costModels = model.usageCost?.days.first(where: { $0.date == displayUsageDate })?.models ?? []
        }
        return costModels.first(where: { $0.model == item.model })?.totalCost
    }

    private func cost(for date: String) -> Decimal? {
        if model.selectedPeriod == .last7Days {
            let allDays = (model.usageCost?.days ?? []) + (model.previousMonthUsageCost?.days ?? [])
            return allDays.first(where: { $0.date == date })?.totalCost
        }
        return model.usageCost?.days.first(where: { $0.date == date })?.totalCost
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
        let index = modelName.flatMap { chartModelNames.firstIndex(of: $0) } ?? fallbackIndex
        let palette = [
            Color(red: 1.00, green: 0.63, blue: 0.04),
            Color(red: 1.00, green: 0.82, blue: 0.10),
            Color(red: 0.23, green: 0.52, blue: 0.96),
            Color(red: 0.24, green: 0.68, blue: 0.43),
            Color(red: 0.63, green: 0.42, blue: 0.94)
        ]
        return palette[index % palette.count]
    }

    private func modelBadge(_ modelName: String, index: Int) -> String {
        let lower = modelName.lowercased()
        if lower.contains("flash") { return "FL" }
        if lower.contains("reasoner") || lower.contains("r1") { return "R1" }
        if lower.contains("chat") || lower.contains("v3") { return "V3" }
        if lower.contains("pro") { return "PRO" }
        return "M\(index + 1)"
    }

    private func modelShortName(_ modelName: String) -> String {
        modelName
            .replacingOccurrences(of: "deepseek-", with: "")
            .replacingOccurrences(of: "deepseek_", with: "")
    }

    private func compactNumber(_ value: Int) -> String {
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
