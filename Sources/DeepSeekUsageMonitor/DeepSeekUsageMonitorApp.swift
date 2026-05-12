import SwiftUI

@main
struct DeepSeekUsageMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var settingsWindow = SettingsWindowController()

    private var deepSeekIcon: NSImage? {
        // SPM resources for executable targets are in a .bundle next to the binary.
        // Try Bundle.main (for .app) then the binary's directory (for raw executable).
        let candidates: [URL] = {
            var urls: [URL] = []
            // 1. Inside .app bundle Resources/
            if let resourceURL = Bundle.main.resourceURL {
                urls.append(resourceURL)
                urls.append(resourceURL.appendingPathComponent("DeepSeekUsageMonitor_DeepSeekUsageMonitor.bundle"))
            }
            // 2. Next to binary in .build/release/
            if let execURL = Bundle.main.executableURL {
                urls.append(execURL.deletingLastPathComponent().appendingPathComponent("DeepSeekUsageMonitor_DeepSeekUsageMonitor.bundle"))
            }
            // 3. All .bundle directories inside main bundle
            if let enumerator = FileManager.default.enumerator(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for case let url as URL in enumerator {
                    if url.pathExtension == "bundle" {
                        urls.append(url)
                    }
                }
            }
            return urls
        }()

        for base in candidates {
            let fileURL = base.appendingPathComponent("deepseek-logo.pdf")
            if FileManager.default.fileExists(atPath: fileURL.path),
               let image = NSImage(contentsOf: fileURL) {
                image.isTemplate = true
                image.size = NSSize(width: 16, height: 16)
                return image
            }
        }
        return nil
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environmentObject(model)
                .environmentObject(settingsWindow)
                .frame(width: 380)
        } label: {
            HStack(spacing: 10) {
                if model.isBalanceWarning {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                } else if let nsImage = deepSeekIcon {
                    Image(nsImage: nsImage)
                        .renderingMode(.template)
                } else {
                    Image(systemName: "circle.hexagongrid.fill")
                        .foregroundStyle(.blue)
                }
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
