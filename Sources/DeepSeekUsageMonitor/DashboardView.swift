import AppKit
import DeepSeekUsageMonitorCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settingsWindow: SettingsWindowController

    private let panelBorder = Color.black.opacity(0.06)
    private let muted = Color.secondary

    var body: some View {
        VStack(spacing: 0) {
            if model.isBalanceWarning {
                warningBanner
            }
            header
            balanceSection
            usageSection
            footer
        }
        .background(.ultraThinMaterial)
        .task {
            if model.userSummary == nil && model.usageAmount == nil {
                await model.refreshAll()
            }
        }
    }

    private var warningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("余额不足 \(model.balanceWarningThreshold.formatted(.number.precision(.fractionLength(0...2)))) 元，请及时充值")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.orange)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.16))
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Text("DS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(
                        LinearGradient(colors: [Color(red: 0.31, green: 0.43, blue: 0.97), Color(red: 0.15, green: 0.39, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                Text("DeepSeek 开放平台")
                    .font(.system(size: 13, weight: .semibold))
                #if DEBUG
                Text("(Dev)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                #endif
            }
            Spacer()
            Button {
                Task { await model.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .rotationEffect((model.isRefreshingBalance || model.isRefreshingUsage) ? .degrees(180) : .zero)
            }
            .buttonStyle(IconButtonStyle())
            .disabled(model.isRefreshingBalance || model.isRefreshingUsage)
            .help("刷新数据")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let summary = model.userSummary

            HStack(spacing: 12) {
                balanceDetail(title: "充值余额", value: money(summary?.normalBalance, currency: summary?.primaryCurrency))
                balanceDetail(title: "本月费用", value: money(summary?.monthlyCost, currency: summary?.primaryCurrency))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TOKEN 用量")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(muted)
                Spacer()
                Picker("", selection: $model.selectedPeriod) {
                    Text("今日").tag(UsagePeriod.today)
                    Text("本月").tag(UsagePeriod.month)
                }
                .pickerStyle(.segmented)
                .frame(width: 108)
            }

            HStack(spacing: 8) {
                Button {
                    model.moveToPreviousMonth()
                    Task { await model.refreshPlatformData() }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(IconButtonStyle())
                .help("查询上个月")

                Text(model.selectedMonthTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                Button {
                    model.moveToNextMonth()
                    Task { await model.refreshPlatformData() }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(IconButtonStyle())
                .disabled(!model.canMoveToNextMonth)
                .help("查询下个月")
            }

            HStack(spacing: 12) {
                statCard(
                    title: "Token 消耗",
                    value: compactNumber(displayUsage.totalTokens),
                    subtitle: "输入 \(compactNumber(displayUsage.inputTokens)) · 输出 \(compactNumber(displayUsage.responseTokens))",
                    accent: .blue
                )
                statCard(
                    title: "请求次数",
                    value: compactNumber(displayUsage.requestCount),
                    subtitle: model.selectedMonthTitle,
                    accent: .green
                )
                statCard(
                    title: usageCostTitle,
                    value: money(displayCost, currency: model.usageCost?.currency ?? model.userSummary?.primaryCurrency),
                    subtitle: usageCostSubtitle,
                    accent: .orange
                )
            }

            miniChart
            modelDistribution
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var miniChart: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .bottom, spacing: 3) {
                let days = chartDays
                let maxValue = max(days.map(\.totalTokens).max() ?? 1, 1)
                ForEach(days) { day in
                    cacheSegmentedBarWithRatio(day: day, maxValue: maxValue)
                }
            }
            .frame(height: 76)

            HStack(spacing: 10) {
                let models = chartModelNames
                ForEach(Array(models.prefix(3).enumerated()), id: \.element) { index, modelName in
                    chartLegend(color: modelColor(modelName, fallbackIndex: index), title: modelShortName(modelName))
                }
                if models.count > 3 {
                    chartLegend(color: modelColor("other", fallbackIndex: 3), title: "其他")
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 4)
    }

    private var modelDistribution: some View {
        VStack(spacing: 8) {
            ForEach(Array(displayUsage.models.enumerated()), id: \.element.id) { index, item in
                modelRow(item, index: index)
                modelUsageBar(item, index: index)
                    .padding(.bottom, index == displayUsage.models.count - 1 ? 0 : 4)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                settingsWindow.show(model: model)
            } label: {
                Label("设置", systemImage: "gearshape")
            }
            .buttonStyle(FooterButtonStyle(kind: .secondary))

            Button {
                NSWorkspace.shared.open(URL(string: "https://platform.deepseek.com/usage")!)
            } label: {
                Label("打开控制台", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(FooterButtonStyle(kind: .primary))

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("退出应用")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.025))
    }

    private func balanceDetail(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func statCard(title: String, value: String, subtitle: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(LinearGradient(colors: [accent.opacity(0.72), accent], startPoint: .leading, endPoint: .trailing))
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .padding(.horizontal, -14)
                .padding(.top, -14)
                .padding(.bottom, 7)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func modelRow(_ item: UsageModelAmount, index: Int) -> some View {
        HStack(spacing: 10) {
            Text(modelBadge(item.model, index: index))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .frame(width: 28, height: 28)
                .foregroundStyle(modelColor(item.model, fallbackIndex: index))
                .background(modelColor(item.model, fallbackIndex: index).opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.model)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(modelDescription(item))
                    .font(.system(size: 11))
                    .foregroundStyle(muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(compactNumber(item.totalTokens))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("\(Int((percentage(for: item) * 100).rounded()))% · \(money(cost(for: item), currency: model.usageCost?.currency))")
                    .font(.system(size: 11))
                    .foregroundStyle(muted)
            }
        }
    }

    private func modelUsageBar(_ item: UsageModelAmount, index: Int) -> some View {
        let totalRatio = percentage(for: item)
        let hitRatio = cacheHitRatio(for: item)

        return GeometryReader { proxy in
            let totalWidth = max(4, proxy.size.width * totalRatio)
            let hitWidth = max(0, totalWidth * hitRatio)

            let modelColor = modelColor(item.model, fallbackIndex: index)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.06))
                Capsule()
                    .fill(modelColor.opacity(0.2))
                    .frame(width: totalWidth)
                Capsule()
                    .fill(modelColor)
                    .frame(width: hitWidth)
            }
        }
        .frame(height: 4)
        .help("\(item.model): 缓存命中率 \(Int((hitRatio * 100).rounded()))%")
    }

    private func cacheSegmentedBarWithRatio(day: UsageDayAmount, maxValue: Int) -> some View {
        let totalTokens = day.totalTokens
        let cacheHitTokens = cacheHitTokens(for: day)
        let barHeight = totalTokens > 0 ? CGFloat(max(4, Int(Double(totalTokens) / Double(maxValue) * 60))) : 4
        let hitRatio = totalTokens > 0 ? Double(cacheHitTokens) / Double(totalTokens) : 0

        return VStack(spacing: 3) {
            if totalTokens > 0 {
                Text("\(Int((hitRatio * 100).rounded()))%")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(height: 10)
            } else {
                Spacer()
                    .frame(height: 10)
            }

            modelSegmentedBar(day: day, barHeight: barHeight)

            let dayLabel = day.date.components(separatedBy: "-").last ?? day.date
            Text(dayLabel)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(muted)
                .lineLimit(1)
                .frame(height: 10)
        }
        .frame(maxHeight: 86, alignment: .bottom)
        .help(chartHelpText(for: day, totalTokens: totalTokens, cacheHitTokens: cacheHitTokens, hitRatio: hitRatio))
    }

    private func modelSegmentedBar(day: UsageDayAmount, barHeight: CGFloat) -> some View {
        return VStack(spacing: 0) {
            ForEach(Array(chartSegments(for: day).enumerated()), id: \.element.model) { index, segment in
                Rectangle()
                    .fill(modelColor(segment.model, fallbackIndex: index))
                    .frame(height: max(2, barHeight * segment.ratio))
            }
        }
        .frame(height: barHeight, alignment: .bottom)
        .frame(maxHeight: 60, alignment: .bottom)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .opacity(day.totalTokens > 0 ? 1 : 0.35)
    }

    private func chartLegend(color: Color, title: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(muted)
        }
    }

    private var displayUsage: UsageDisplay {
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

    private var chartDays: [UsageDayAmount] {
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

    private var todayCost: Decimal? {
        cost(for: todayDateString())
    }

    private var displayCost: Decimal? {
        if model.selectedPeriod == .month {
            return model.usageCost?.totalCost
        }
        return todayCost
    }

    private var usageCostTitle: String {
        model.selectedPeriod == .month ? "本月花费" : "今日花费"
    }

    private var usageCostSubtitle: String {
        model.selectedPeriod == .month ? model.selectedMonthTitle : todayDateString()
    }

    private func cost(for date: String) -> Decimal? {
        model.usageCost?.days.first(where: { $0.date == date })?.totalCost
    }

    private func cost(for item: UsageModelAmount) -> Decimal? {
        let costModels: [UsageCostModelAmount]
        if model.selectedPeriod == .month {
            costModels = model.usageCost?.models ?? []
        } else {
            costModels = model.usageCost?.days.first(where: { $0.date == displayUsageDate })?.models ?? []
        }
        return costModels.first(where: { $0.model == item.model })?.totalCost
    }

    private func money(_ value: Decimal?, currency: String?) -> String {
        guard let value else {
            return "--"
        }
        let symbol = currency?.uppercased() == "CNY" || currency == nil ? "¥" : "\(currency ?? "") "
        let number = NSDecimalNumber(decimal: value).doubleValue
        return "\(symbol)\(String(format: "%.2f", number))"
    }

    private func percentage(for item: UsageModelAmount) -> Double {
        guard displayUsage.totalTokens > 0 else {
            return 0
        }
        return Double(item.totalTokens) / Double(displayUsage.totalTokens)
    }

    private func cacheHitRatio(for item: UsageModelAmount) -> Double {
        guard item.totalTokens > 0 else {
            return 0
        }
        return Double(item.promptCacheHitTokens) / Double(item.totalTokens)
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

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func modelBadge(_ model: String, index: Int) -> String {
        if model.localizedCaseInsensitiveContains("flash") {
            return "F"
        }
        if model.localizedCaseInsensitiveContains("reasoner") {
            return "R1"
        }
        if model.localizedCaseInsensitiveContains("chat") {
            return "V3"
        }
        return index == 0 ? "PRO" : "M\(index + 1)"
    }

    private func modelDescription(_ item: UsageModelAmount) -> String {
        let ratio = cacheHitRatio(for: item)
        return "缓存命中率 \(Int((ratio * 100).rounded()))%"
    }

    private func cacheHitTokens(for day: UsageDayAmount) -> Int {
        day.models.reduce(0) { $0 + $1.promptCacheHitTokens }
    }

    private func chartSegments(for day: UsageDayAmount) -> [(model: String, ratio: Double)] {
        guard day.totalTokens > 0 else {
            return []
        }

        return day.models
            .filter { $0.totalTokens > 0 }
            .sorted { lhs, rhs in
                modelSortIndex(lhs.model) < modelSortIndex(rhs.model)
            }
            .map { item in
                (model: item.model, ratio: Double(item.totalTokens) / Double(day.totalTokens))
            }
    }

    private func modelSortIndex(_ modelName: String) -> Int {
        chartModelNames.firstIndex(of: modelName) ?? Int.max
    }

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

    private func modelShortName(_ modelName: String) -> String {
        modelName
            .replacingOccurrences(of: "deepseek-", with: "")
            .replacingOccurrences(of: "deepseek_", with: "")
    }

    private func chartHelpText(for day: UsageDayAmount, totalTokens: Int, cacheHitTokens: Int, hitRatio: Double) -> String {
        let modelBreakdown = day.models
            .filter { $0.totalTokens > 0 }
            .sorted { $0.totalTokens > $1.totalTokens }
            .map { "\($0.model) \(compactNumber($0.totalTokens))" }
            .joined(separator: " · ")

        let modelText = modelBreakdown.isEmpty ? "" : " · \(modelBreakdown)"
        return "\(day.date): \(totalTokens.formatted()) tokens\(modelText) · 缓存命中 \(compactNumber(cacheHitTokens)) (\(Int((hitRatio * 100).rounded()))%) · 花费 \(money(cost(for: day.date), currency: model.usageCost?.currency))"
    }
}

private struct UsageDisplay {
    static let empty = UsageDisplay(models: [])

    let models: [UsageModelAmount]

    init(models: [UsageModelAmount]) {
        self.models = models.filter { $0.totalTokens > 0 }
    }

    var requestCount: Int {
        models.reduce(0) { $0 + $1.requestCount }
    }

    var inputTokens: Int {
        models.reduce(0) { $0 + $1.inputTokens }
    }

    var responseTokens: Int {
        models.reduce(0) { $0 + $1.responseTokens }
    }

    var totalTokens: Int {
        inputTokens + responseTokens
    }
}

private struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 24, height: 24)
            .foregroundStyle(.secondary)
            .background(configuration.isPressed ? Color.black.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct FooterButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(kind == .primary ? .white : .primary)
            .background(background(configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func background(_ isPressed: Bool) -> some ShapeStyle {
        if kind == .primary {
            return AnyShapeStyle(LinearGradient(colors: [Color(red: 0.31, green: 0.43, blue: 0.97), Color(red: 0.15, green: 0.39, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(Color.black.opacity(isPressed ? 0.1 : 0.055))
    }
}
