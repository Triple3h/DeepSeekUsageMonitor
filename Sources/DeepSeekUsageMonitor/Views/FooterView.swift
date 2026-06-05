import AppKit
import SwiftUI

struct FooterView: View {
    @EnvironmentObject private var model: AppModel
    var onOpenConsole: () -> Void
    var onQuit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    model.isSettingsShown.toggle()
                }
            } label: {
                Label(model.isSettingsShown ? "返回" : "设置", systemImage: model.isSettingsShown ? "chevron.left" : "gearshape")
            }
            .buttonStyle(FooterButtonStyle(kind: .secondary))

            Button {
                onOpenConsole()
            } label: {
                Label("打开控制台", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(FooterButtonStyle(kind: .primary))

            Spacer()

            Button {
                onQuit()
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("退出应用")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.06))
    }
}

// MARK: - Shared Button Styles

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 24, height: 24)
            .foregroundStyle(.secondary)
            .background(configuration.isPressed ? Color.primary.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct FooterButtonStyle: ButtonStyle {
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
            return AnyShapeStyle(Theme.brandGradient)
        }
        return AnyShapeStyle(Color.primary.opacity(isPressed ? 0.1 : 0.06))
    }
}
