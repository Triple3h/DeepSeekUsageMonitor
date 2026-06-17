import AppKit
import SwiftUI

struct HeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Text("API 费用监控")
                    .font(.system(size: 15, weight: .bold))
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

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    model.isSettingsShown.toggle()
                }
            } label: {
                Image(systemName: model.isSettingsShown ? "chevron.left" : "gearshape")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help(model.isSettingsShown ? "返回" : "设置")

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
        .padding(.top, 14)
        .padding(.bottom, 18)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.35)
        }
    }
}
