import SwiftUI

@main
struct DeepSeekUsageMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarManager = MenuBarManager()
        menuBarManager?.startAutoRefresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarManager?.cleanup()
    }
}
