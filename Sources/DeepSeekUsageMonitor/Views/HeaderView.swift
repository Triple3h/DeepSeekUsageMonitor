import SwiftUI

struct HeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Text("DS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Theme.brandGradient)
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
                    .animation(.easeInOut(duration: 0.4), value: model.isRefreshingBalance || model.isRefreshingUsage)
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
}
