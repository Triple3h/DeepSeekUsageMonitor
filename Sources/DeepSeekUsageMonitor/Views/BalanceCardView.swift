import AppKit
import SwiftUI
import DeepSeekUsageMonitorCore

struct BalanceCardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            if model.deepSeekEnabled || model.mimoEnabled {
                platformBalanceOverview
            }
        }
    }

    // MARK: - 平台余额概览

    private var platformBalanceOverview: some View {
        VStack(spacing: 6) {
            HStack {
                Text("平台余额")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let combinedCost = model.combinedMonthCost {
                    Text("本月合计 -\(money(combinedCost, currency: nil))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
            }

            // 数据驱动：遍历所有平台行
            ForEach(platformRows) { row in
                PlatformRowView(row: row)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - 平台行数据模型

    struct PlatformBalanceRow: Identifiable {
        let id: String
        let name: String
        let shortLabel: String
        let accentColor: Color

        /// 计费类型：决定是否展示进度条
        let billingType: BillingType

        /// 右侧主数字
        let primaryValue: String?
        /// 右侧副标题
        let secondaryValue: String?

        /// 进度条（仅 quotaBased 有效）
        let progress: Double?

        /// 下方明细标签
        let details: [DetailItem]

        /// 平台控制台跳转地址
        let platformURL: URL?

        enum BillingType {
            /// 按量计费：只显示数字，无进度条
            case payAsYouGo
            /// 套餐/配额制：显示进度条（Token Plan、Coding Plan 等）
            case quotaBased
        }

        struct DetailItem: Identifiable {
            let id = UUID()
            let title: String
            let value: String
        }
    }

    // MARK: - 平台行构建（可扩展）

    private var platformRows: [PlatformBalanceRow] {
        var rows: [PlatformBalanceRow] = []

        // DeepSeek — 按量计费
        if model.deepSeekEnabled {
            rows.append(deepSeekRow)
        }

        // Mimo — 根据计费模式决定
        if model.mimoEnabled {
            if model.mimoBillingMode == .tokenPlan {
                rows.append(mimoTokenPlanRow)
            } else {
                rows.append(mimoPayAsYouGoRow)
            }
        }

        return rows
    }

    // MARK: - DeepSeek 行

    private var deepSeekRow: PlatformBalanceRow {
        PlatformBalanceRow(
            id: "deepseek",
            name: "DeepSeek",
            shortLabel: "DS",
            accentColor: Color(red: 0.30, green: 0.42, blue: 0.99),
            billingType: .payAsYouGo,
            primaryValue: model.userSummary.map { money($0.monthlyCost, currency: $0.primaryCurrency) },
            secondaryValue: nil,
            progress: nil,
            details: [
                .init(title: "充值", value: money(model.userSummary?.normalBalance, currency: model.userSummary?.primaryCurrency)),
                .init(title: "赠送", value: money(model.userSummary?.bonusBalance, currency: model.userSummary?.primaryCurrency))
            ],
            platformURL: URL(string: "https://platform.deepseek.com/usage")
        )
    }

    // MARK: - Mimo 按量计费行

    private var mimoPayAsYouGoRow: PlatformBalanceRow {
        PlatformBalanceRow(
            id: "mimo_payg",
            name: "Mimo",
            shortLabel: "M",
            accentColor: Color(red: 1.00, green: 0.42, blue: 0.21),
            billingType: .payAsYouGo,
            primaryValue: model.mimoUsageOverview.map { money($0.currentMonthCost, currency: nil) },
            secondaryValue: nil,
            progress: nil,
            details: [
                .init(title: "账户", value: money(model.mimoBalance?.balance, currency: model.mimoBalance?.currency)),
                .init(title: "赠送", value: money(model.mimoBalance?.giftBalance, currency: model.mimoBalance?.currency))
            ],
            platformURL: URL(string: "https://platform.xiaomimimo.com/console/usage")
        )
    }

    // MARK: - Mimo Token Plan 行

    private var mimoTokenPlanRow: PlatformBalanceRow {
        PlatformBalanceRow(
            id: "mimo_token_plan",
            name: "Mimo",
            shortLabel: "M",
            accentColor: Color(red: 1.00, green: 0.42, blue: 0.21),
            billingType: .quotaBased,
            primaryValue: model.mimoTokenPlanUsage.map { compactNumber($0.usedTokens) },
            secondaryValue: model.mimoTokenPlanUsage.map { "已用 \(String(format: "%.0f%%", $0.usagePercent * 100))" },
            progress: model.mimoTokenPlanUsage.map { $0.usagePercent },
            details: [
                .init(title: "", value: "0%"),
                .init(title: "", value: "50%"),
                .init(title: "", value: "100%")
            ],
            platformURL: URL(string: "https://platform.xiaomimimo.com/console/plan-manage")
        )
    }

    // MARK: - Helpers

    private func money(_ value: Double?, currency: String?) -> String {
        guard let value else { return "--" }
        let symbol = currency?.uppercased() == "CNY" || currency == nil ? "¥" : "\(currency ?? "") "
        return "\(symbol)\(String(format: "%.2f", value))"
    }

    private func money(_ value: Decimal?, currency: String?) -> String {
        guard let value else { return "--" }
        return money(NSDecimalNumber(decimal: value).doubleValue, currency: currency)
    }

    private func compactNumber(_ value: Int?) -> String {
        guard let value else { return "--" }
        if value >= 1_000_000_000 {
            return String(format: "%.1fB", Double(value) / 1_000_000_000)
        }
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return value.formatted()
    }
}

// MARK: - 平台行视图

struct PlatformRowView: View {
    let row: BalanceCardView.PlatformBalanceRow

    private static let deepseekNSImage: NSImage? = {
        ResourceBundle.url(forResource: "deepseek-logo", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    }()

    private static let mimoNSImage: NSImage? = {
        ResourceBundle.url(forResource: "mimo-logo", withExtension: "png").flatMap { NSImage(contentsOf: $0) }
    }()

    var body: some View {
        HStack(spacing: 10) {
            // 平台图标
            if let nsImg = platformImage {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else {
                Text(row.shortLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(row.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(row.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                // 进度条：仅配额制平台显示
                if row.billingType == .quotaBased, let progress = row.progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(nsColor: .quaternaryLabelColor))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(row.accentColor)
                                .frame(width: geo.size.width * min(max(progress, 0), 1.0), height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                // 明细标签
                detailLabels
            }

            Spacer()

            // 右侧：主数字 + 跳转按钮
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    if let primary = row.primaryValue {
                        Text(primary)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                    } else {
                        Text("--")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.orange)
                    }

                    if let url = row.platformURL {
                        Link(destination: url) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.quaternary)
                                .frame(width: 14, height: 14)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                        .help("打开 \(row.name) 控制台")
                    }
                }

                if let secondary = row.secondaryValue {
                    Text(secondary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var platformImage: NSImage? {
        switch row.id {
        case "deepseek": return Self.deepseekNSImage
        case "mimo_payg", "mimo_token_plan": return Self.mimoNSImage
        default: return nil
        }
    }

    private var detailLabels: some View {
        let n = row.details.count
        return HStack(spacing: 0) {
            ForEach(0..<n, id: \.self) { idx in
                DetailLabel(title: row.details[idx].title, value: row.details[idx].value)
                    .frame(maxWidth: .infinity, alignment: idx == 0 ? .leading : (idx == n - 1 ? .trailing : .center))
            }
        }
    }
}

// MARK: - 明细标签

private struct DetailLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .foregroundStyle(.tertiary)
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.system(size: 10))
    }
}
