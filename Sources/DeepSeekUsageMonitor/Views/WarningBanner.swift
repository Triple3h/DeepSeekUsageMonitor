import SwiftUI

struct WarningBanner: View {
    let threshold: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("余额不足 \(threshold.formatted(.number.precision(.fractionLength(0...2)))) 元，请及时充值")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.orange)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.16))
    }
}
