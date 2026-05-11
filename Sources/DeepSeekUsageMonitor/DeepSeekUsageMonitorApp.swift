import SwiftUI

@main
struct DeepSeekUsageMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var settingsWindow = SettingsWindowController()

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environmentObject(model)
                .environmentObject(settingsWindow)
                .frame(width: 340)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.isBalanceWarning ? "exclamationmark.circle.fill" : "circle.hexagongrid.fill")
                    .foregroundStyle(model.isBalanceWarning ? .red : .blue)
                Text(menuBarBalanceText)
                    .font(.system(size: 12, weight: model.isBalanceWarning ? .semibold : .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(model.isBalanceWarning ? .red : .primary)
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarBalanceText: String {
        guard let summary = model.userSummary else {
            return "DeepSeek"
        }
        return "\(currencySymbol(summary.primaryCurrency))\(money(summary.totalBalance))"
    }

    private func currencySymbol(_ currency: String) -> String {
        currency.uppercased() == "CNY" ? "¥" : "\(currency) "
    }

    private func money(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        return String(format: "%.2f", number.doubleValue)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
