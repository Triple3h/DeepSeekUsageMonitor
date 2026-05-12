import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("网页端接口凭证") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bearer Token")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        PasteableTextView(text: $model.platformBearerDraft, height: 72)
                            .frame(height: 72)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )

                        Text("Cookie")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        PasteableTextView(text: $model.platformCookieDraft, height: 100)
                            .frame(height: 100)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )

                        Text("余额请求：/api/v0/users/get_user_summary；Token 用量请求：/api/v0/usage/amount?month=...&year=...；费用请求：/api/v0/usage/cost?month=...&year=...。敏感信息保存到 macOS Keychain。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("菜单栏预警") {
                    LabeledContent("余额预警阈值") {
                        HStack(spacing: 4) {
                            TextField("", text: $model.balanceWarningThresholdDraft)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("元")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("自动刷新间隔") {
                        HStack(spacing: 4) {
                            TextField("", text: $model.autoRefreshMinutesDraft)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("分钟")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle("开机自动启动", isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    ))

                    Text("余额低于阈值时，菜单栏图标和面板顶部会显示红色提醒。查询月份默认当前月，历史月份在主面板里用左右箭头切换。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                #if DEBUG
                Section("调试") {
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
                #endif
            }
            .formStyle(.grouped)

            Divider()

            HStack(spacing: 12) {
                Button("保存设置") {
                    model.saveSettings()
                }
                .buttonStyle(.borderedProminent)

                Button("刷新平台数据") {
                    model.saveSettings()
                    Task { await model.refreshPlatformData() }
                }

                Spacer()

                Group {
                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else {
                        Text(model.statusMessage)
                    }
                }
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
