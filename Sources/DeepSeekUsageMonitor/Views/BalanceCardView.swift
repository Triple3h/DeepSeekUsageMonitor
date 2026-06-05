import SwiftUI

struct BalanceCardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let summary = model.userSummary

        HStack(spacing: 12) {
            balanceDetail(title: "充值余额", value: money(summary?.normalBalance, currency: summary?.primaryCurrency))
            balanceDetail(title: "本月费用", value: money(summary?.monthlyCost, currency: summary?.primaryCurrency))
        }
    }

    private func balanceDetail(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func money(_ value: Decimal?, currency: String?) -> String {
        guard let value else { return "--" }
        let symbol = currency?.uppercased() == "CNY" || currency == nil ? "¥" : "\(currency ?? "") "
        let number = NSDecimalNumber(decimal: value).doubleValue
        return "\(symbol)\(String(format: "%.2f", number))"
    }
}
