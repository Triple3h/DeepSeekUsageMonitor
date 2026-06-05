import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        model.isSettingsShown = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("返回")
                            .font(.subheadline)
                    }
                    .foregroundStyle(Theme.brand)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("设置")
                    .font(.headline)

                Spacer()

                // 占位，保持标题居中
                Color.clear.frame(width: 50, height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            VStack(spacing: 12) {
                credentialSection
                warningSection
                debugSection
                saveActions
            }
            .padding(16)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // 底部栏（跟 DashboardView 的 FooterView 保持一致）
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        model.isSettingsShown = false
                    }
                } label: {
                    Label("返回面板", systemImage: "chevron.left")
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
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    // MARK: - 凭证

    private var credentialSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("网页端接口凭证", systemImage: "key.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.brand)

                credentialRow(label: "Bearer Token", text: $model.platformBearerDraft, height: 64)

                credentialRow(label: "Cookie", text: $model.platformCookieDraft, height: 88)

                Text("敏感信息保存到 macOS Keychain，不会上传到任何服务器。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func credentialRow(label: String, text: Binding<String>, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            PasteableTextView(text: text, height: height)
                .frame(height: height)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.panelBorder(for: colorScheme), lineWidth: 0.5)
                )
        }
    }

    // MARK: - 预警

    private var warningSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("菜单栏预警", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.brand)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("余额预警阈值")
                            .foregroundStyle(.primary)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("", text: $model.balanceWarningThresholdDraft)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 72)
                            Text("元")
                                .foregroundStyle(.tertiary)
                        }
                    }

                    HStack {
                        Text("自动刷新间隔")
                            .foregroundStyle(.primary)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("", text: $model.autoRefreshMinutesDraft)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("分钟")
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    )) {
                        Text("开机自动启动")
                            .foregroundStyle(.primary)
                    }
                    .toggleStyle(.checkbox)
                }

                Text("余额低于阈值时，菜单栏图标和面板顶部会显示红色提醒。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - 调试

    @ViewBuilder
    private var debugSection: some View {
        #if DEBUG
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("调试", systemImage: "ladybug.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.brand)

                if let usage = model.usageAmount {
                    debugDisclosure(title: "Token 用量原始 JSON", json: usage.rawJSON)
                }
                if let cost = model.usageCost {
                    debugDisclosure(title: "费用原始 JSON", json: cost.rawJSON)
                }
                if let summary = model.userSummary {
                    debugDisclosure(title: "账户摘要原始 JSON", json: summary.rawJSON)
                }
            }
        }
        #endif
    }

    private func debugDisclosure(title: String, json: String) -> some View {
        DisclosureGroup(title) {
            ScrollView {
                Text(json)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 120)
        }
        .font(.subheadline)
    }

    // MARK: - 保存/刷新

    private var saveActions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    model.saveSettings()
                } label: {
                    Label("保存设置", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand)

                Button {
                    model.saveSettings()
                    Task { await model.refreshPlatformData() }
                } label: {
                    Label("刷新数据", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.bordered)
                .tint(Theme.brand)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            } else if !model.statusMessage.isEmpty && model.statusMessage != "未刷新" {
                Text(model.statusMessage)
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
        }
    }
}
