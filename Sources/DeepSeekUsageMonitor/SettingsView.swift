import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("网页端接口凭证") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bearer Token")
                        .font(.caption.weight(.semibold))
                    PasteableTextView(text: $model.platformBearerDraft, height: 72)
                        .frame(height: 72)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("Cookie")
                        .font(.caption.weight(.semibold))
                    PasteableTextView(text: $model.platformCookieDraft, height: 100)
                        .frame(height: 100)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("余额请求：/api/v0/users/get_user_summary；Token 用量请求：/api/v0/usage/amount?month=...&year=...；费用请求：/api/v0/usage/cost?month=...&year=...。敏感信息保存到 macOS Keychain。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            GroupBox("菜单栏预警") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("余额预警阈值（元）", text: $model.balanceWarningThresholdDraft)
                        .textFieldStyle(.roundedBorder)
                    TextField("自动刷新间隔（分钟）", text: $model.autoRefreshMinutesDraft)
                        .textFieldStyle(.roundedBorder)
                    Toggle("开机自动启动", isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    Text("余额低于阈值时，菜单栏图标和面板顶部会显示红色提醒。查询月份默认当前月，历史月份在主面板里用左右箭头切换。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            GroupBox("调试") {
                VStack(alignment: .leading, spacing: 8) {
                if let usage = model.usageAmount {
                    DisclosureGroup("Token 用量原始 JSON") {
                        ScrollView {
                            Text(usage.rawJSON)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 140)
                    }
                }
                if let cost = model.usageCost {
                    DisclosureGroup("费用原始 JSON") {
                        ScrollView {
                            Text(cost.rawJSON)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 140)
                    }
                }
                if let summary = model.userSummary {
                    DisclosureGroup("账户摘要原始 JSON") {
                        ScrollView {
                            Text(summary.rawJSON)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 140)
                    }
                }
                }
                .padding(.top, 4)
            }

            HStack {
                Button("保存设置") {
                    model.saveSettings()
                }
                Button("刷新平台数据") {
                    model.saveSettings()
                    Task { await model.refreshPlatformData() }
                }
                Spacer()
                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else {
                    Text(model.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}
