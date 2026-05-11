import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: ObservableObject {
    private var window: NSWindow?

    func show(model: AppModel) {
        NSApp.setActivationPolicy(.accessory)
        if let window {
            activate(window)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView()
                .environmentObject(model)
                .frame(width: 560, height: 520)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "DeepSeek 设置"
        window.setContentSize(NSSize(width: 560, height: 520))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        self.window = window
        activate(window)
    }

    private func activate(_ window: NSWindow) {
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)

        DispatchQueue.main.async {
            NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            window.makeKey()
            window.makeMain()
            window.makeFirstResponder(window.contentView?.firstTextView)
        }
    }
}

private extension NSView {
    var firstTextView: NSTextView? {
        if let textView = self as? NSTextView {
            return textView
        }
        for subview in subviews {
            if let textView = subview.firstTextView {
                return textView
            }
        }
        return nil
    }
}
