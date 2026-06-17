import DeepSeekUsageMonitorCore
import SwiftUI

struct UsageSectionView: View {
    @EnvironmentObject private var model: AppModel
    let displayUsage: UsageDisplay
    let displayCost: Decimal?
    let chartDays: [UsageDayAmount]
    let chartModelNames: [String]
    let modelColor: (String?, Int) -> Color
    let modelBadge: (String, Int) -> String
    let modelShortName: (String) -> String
    let costForModel: (UsageModelAmount) -> Decimal?
    let compactNumber: (Int) -> String
    let money: (Decimal?, String?) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TOKEN 用量")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()

                Picker("", selection: $model.selectedPeriod) {
                    Text("今日").tag(UsagePeriod.today)
                    Text("近7日").tag(UsagePeriod.last7Days)
                    Text("本月").tag(UsagePeriod.month)
                }
                .pickerStyle(.segmented)
                .frame(width: 142)
                .onChange(of: model.selectedPeriod) { newPeriod in
                    if newPeriod == .last7Days {
                        Task { await model.refreshPreviousMonthDataIfNeeded() }
                    }
                }
            }

            HStack(spacing: 8) {
                if model.selectedPeriod == .last7Days {
                    Text("近7日")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                } else {
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
            }

            HStack(spacing: 8) {
                StatCardView(
                    title: "Token 消耗",
                    value: compactNumber(displayUsage.totalTokens),
                    subtitle: "\(compactNumber(displayUsage.inputTokens)) / \(compactNumber(displayUsage.responseTokens))",
                    accent: .blue
                )
                StatCardView(
                    title: "请求次数",
                    value: compactNumber(displayUsage.requestCount),
                    subtitle: model.selectedMonthTitle,
                    accent: .green
                )
                StatCardView(
                    title: usageCostTitle,
                    value: money(displayCost, model.usageCost?.currency ?? model.userSummary?.primaryCurrency),
                    subtitle: usageCostSubtitle,
                    accent: .orange
                )
            }

            MiniChartView(
                chartDays: chartDays,
                chartModelNames: chartModelNames,
                modelColor: modelColor,
                modelShortName: modelShortName
            )

            ModelDistributionView(
                models: displayUsage.models,
                totalTokens: displayUsage.totalTokens,
                usageCostCurrency: model.usageCost?.currency,
                modelColor: modelColor,
                modelBadge: modelBadge,
                costForModel: costForModel,
                compactNumber: compactNumber,
                money: money
            )
        }
    }

    private var usageCostTitle: String {
        switch model.selectedPeriod {
        case .month: return "本月花费"
        case .last7Days: return "近7日花费"
        case .today: return "今日花费"
        }
    }

    private var usageCostSubtitle: String {
        switch model.selectedPeriod {
        case .month: return model.selectedMonthTitle
        case .last7Days: return last7DaysDateRangeString()
        case .today: return todayDateString()
        }
    }

    private func last7DaysDateRangeString() -> String {
        let dates = model.last7DaysDateStrings()
        guard let first = dates.first, let last = dates.last else { return "" }
        return "\(first) 至 \(last)"
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

}
