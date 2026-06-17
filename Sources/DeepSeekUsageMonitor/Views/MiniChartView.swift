import DeepSeekUsageMonitorCore
import SwiftUI

struct MiniChartView: View {
    let chartDays: [UsageDayAmount]
    let chartModelNames: [String]
    let modelColor: (String?, Int) -> Color
    let modelShortName: (String) -> String

    private let muted = Color.secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .bottom, spacing: 3) {
                let maxValue = max(chartDays.map(\.totalTokens).max() ?? 1, 1)
                ForEach(chartDays) { day in
                    ChartBar(day: day, maxValue: maxValue, chartModelNames: chartModelNames, modelColor: modelColor)
                }
            }
            .frame(height: 88)

            HStack(spacing: 10) {
                ForEach(Array(chartModelNames.prefix(3).enumerated()), id: \.element) { index, modelName in
                    chartLegend(color: modelColor(modelName, index), title: modelShortName(modelName))
                }
                if chartModelNames.count > 3 {
                    chartLegend(color: modelColor("other", 3), title: "其他")
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
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
}

private struct ChartBar: View {
    let day: UsageDayAmount
    let maxValue: Int
    let chartModelNames: [String]
    let modelColor: (String?, Int) -> Color

    private let muted = Color.secondary

    var body: some View {
        let total = day.totalTokens
        let hitTokens = day.models.reduce(0) { $0 + $1.promptCacheHitTokens }
        let hasData = total > 0
        // 有数据时按比例计算高度，无数据时显示最小占位柱体
        let barHeight: CGFloat = hasData
            ? CGFloat(max(6, Int(Double(total) / Double(maxValue) * 56)))
            : 4
        let hitRatio = hasData ? Double(hitTokens) / Double(total) : 0

        return VStack(spacing: 3) {
            // 柱体
            SegmentedBar(day: day, barHeight: barHeight, chartModelNames: chartModelNames, modelColor: modelColor, hasData: hasData)

            // 日期标签
            let dayLabel = day.date.components(separatedBy: "-").last ?? day.date
            Text(dayLabel)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(muted)
                .lineLimit(1)
                .frame(height: 10)
        }
        .frame(maxHeight: 88, alignment: .bottom)
        .help(hasData
            ? "\(day.date): \(total.formatted()) tokens · 缓存命中 \(hitTokens.formatted()) (\(Int((hitRatio * 100).rounded()))%)"
            : "\(day.date): 无数据"
        )
    }
}

private struct SegmentedBar: View {
    let day: UsageDayAmount
    let barHeight: CGFloat
    let chartModelNames: [String]
    let modelColor: (String?, Int) -> Color
    let hasData: Bool

    var body: some View {
        let segments = chartSegments(for: day)

        ZStack(alignment: .bottom) {
            if hasData {
                // 有数据：显示分段彩色柱体
                VStack(spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.element.model) { index, segment in
                        Rectangle()
                            .fill(modelColor(segment.model, index))
                            .frame(height: max(2, barHeight * segment.ratio))
                            .animation(.easeOut(duration: 0.3), value: barHeight)
                    }
                }
                .frame(height: barHeight, alignment: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            } else {
                // 无数据：显示灰色占位柱体
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 4)
            }
        }
        .frame(height: 66, alignment: .bottom)
    }

    private func chartSegments(for day: UsageDayAmount) -> [(model: String, ratio: Double)] {
        guard day.totalTokens > 0 else { return [] }
        return day.models
            .filter { $0.totalTokens > 0 }
            .sorted { lhs, rhs in
                let lhsIndex = chartModelNames.firstIndex(of: lhs.model) ?? Int.max
                let rhsIndex = chartModelNames.firstIndex(of: rhs.model) ?? Int.max
                return lhsIndex < rhsIndex
            }
            .map { item in
                (model: item.model, ratio: Double(item.totalTokens) / Double(day.totalTokens))
            }
    }
}
