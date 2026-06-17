import AppKit
import DeepSeekUsageMonitorCore
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

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(IconButtonStyle())
                .help("退出应用")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            VStack(spacing: 12) {
                appearanceSection
                deepSeekCredentialSection
                mimoCredentialSection
                warningSection
                debugSection
                saveActions
            }
            .padding(16)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    // MARK: - 外观主题

    private var appearanceSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("外观", systemImage: "paintbrush.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.brand)

                Picker("主题", selection: $model.selectedTheme) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text("选择“跟随系统”将自动适配macOS的深色/浅色模式。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - DeepSeek 凭证

    private var deepSeekCredentialSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("DeepSeek 平台", systemImage: "key.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.brand)
                    Spacer()
                    Toggle("", isOn: $model.deepSeekEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                if model.deepSeekEnabled {
                    credentialRow(label: "Bearer Token", text: $model.platformBearerDraft, height: 88)

                    Text("从 platform.deepseek.com 获取，敏感信息保存到 macOS Keychain，不会上传到任何服务器。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Mimo 凭证

    private var mimoCredentialSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Mimo 平台", systemImage: "key.fill")
                        .font(.headline)
                        .foregroundStyle(Color(red: 1.00, green: 0.42, blue: 0.21)) // Mimo orange color
                    Spacer()
                    Toggle("", isOn: $model.mimoEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                if model.mimoEnabled {
                    // 计费模式选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("计费模式")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("", selection: $model.mimoBillingMode) {
                            Text("按量收费").tag(MimoBillingMode.payAsYouGo)
                            Text("Token Plan").tag(MimoBillingMode.tokenPlan)
                        }
                        .pickerStyle(.segmented)
                    }

                    credentialRow(label: "Cookie（完整字符串）", text: $model.mimoCookieDraft, height: 88)

                    Text("从 platform.xiaomimimo.com 获取，在浏览器开发者工具中复制完整的 Cookie 字符串，敏感信息保存到 macOS Keychain。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
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

                // DeepSeek
                if model.deepSeekEnabled {
                    if let usage = model.usageAmount {
                        debugDisclosure(title: "DeepSeek Token 用量原始 JSON", json: usage.rawJSON)
                    }
                    if let cost = model.usageCost {
                        debugDisclosure(title: "DeepSeek 费用原始 JSON", json: cost.rawJSON)
                    }
                    if let summary = model.userSummary {
                        debugDisclosure(title: "DeepSeek 账户摘要原始 JSON", json: summary.rawJSON)
                    }
                }

                // Mimo
                if model.mimoEnabled {
                    if let balance = model.mimoBalance {
                        debugDisclosure(title: "Mimo 账户余额原始 JSON", json: balance.rawJSON)
                    }
                    if let overview = model.mimoUsageOverview {
                        debugDisclosure(title: "Mimo 使用概览原始 JSON", json: overview.rawJSON)
                    }
                    if let detail = model.mimoUsageDetailReport {
                        debugDisclosure(title: "Mimo 按量详情原始 JSON", json: detail.rawJSON)
                    }
                    if let tokenPlan = model.mimoTokenPlanUsage {
                        debugDisclosure(title: "Mimo Token Plan 使用原始 JSON", json: tokenPlan.rawJSON)
                    }
                    if let tokenPlanDetail = model.mimoTokenPlanDetailReport {
                        debugDisclosure(title: "Mimo Token Plan 详情原始 JSON", json: tokenPlanDetail.rawJSON)
                    }
                }

                if !model.deepSeekEnabled && !model.mimoEnabled {
                    Text("暂无调试数据")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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
