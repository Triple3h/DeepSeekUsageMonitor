import DeepSeekUsageMonitorCore
import SwiftUI

struct ModelDistributionView: View {
    let models: [UsageModelAmount]
    let totalTokens: Int
    let usageCostCurrency: String?
    let modelColor: (String?, Int) -> Color
    let modelBadge: (String, Int) -> String
    let costForModel: (UsageModelAmount) -> Decimal?
    let compactNumber: (Int) -> String
    let money: (Decimal?, String?) -> String

    private let muted = Color.secondary

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(models.enumerated()), id: \.element.id) { index, item in
                modelRow(item, index: index)
                modelUsageBar(item, index: index)
                    .padding(.bottom, index == models.count - 1 ? 0 : 4)
            }
        }
    }

    private func modelRow(_ item: UsageModelAmount, index: Int) -> some View {
        HStack(spacing: 10) {
            Text(modelBadge(item.model, index))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .frame(width: 28, height: 28)
                .foregroundStyle(modelColor(item.model, index))
                .background(modelColor(item.model, index).opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.model)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("缓存命中率 \(Int((cacheHitRatio(for: item) * 100).rounded()))%")
                    .font(.system(size: 11))
                    .foregroundStyle(muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 1) {
                Text(compactNumber(item.totalTokens))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                let ratio = totalTokens > 0 ? Double(item.totalTokens) / Double(totalTokens) : 0
                Text("\(Int((ratio * 100).rounded()))% · \(money(costForModel(item), usageCostCurrency))")
                    .font(.system(size: 11))
                    .foregroundStyle(muted)
            }
        }
    }

    private func modelUsageBar(_ item: UsageModelAmount, index: Int) -> some View {
        let totalRatio = totalTokens > 0 ? Double(item.totalTokens) / Double(totalTokens) : 0
        let hitRatio = cacheHitRatio(for: item)

        return GeometryReader { proxy in
            let totalWidth = max(4, proxy.size.width * totalRatio)
            let hitWidth = max(0, totalWidth * hitRatio)

            let color = modelColor(item.model, index)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(color.opacity(0.2))
                    .frame(width: totalWidth)
                    .animation(.easeOut(duration: 0.3), value: totalWidth)
                Capsule()
                    .fill(color)
                    .frame(width: hitWidth)
                    .animation(.easeOut(duration: 0.3), value: hitWidth)
            }
        }
        .frame(height: 4)
        .help("\(item.model): 缓存命中率 \(Int((hitRatio * 100).rounded()))%")
    }

    private func cacheHitRatio(for item: UsageModelAmount) -> Double {
        guard item.totalTokens > 0 else { return 0 }
        return Double(item.promptCacheHitTokens) / Double(item.totalTokens)
    }
}
