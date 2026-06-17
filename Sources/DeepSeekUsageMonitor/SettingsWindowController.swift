import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsWindowController: ObservableObject {
    private var window: NSWindow?
    private var cancellable: AnyCancellable?

    func show(model: AppModel) {
        NSApp.setActivationPolicy(.accessory)
        if let window {
            activate(window)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView()
                .environmentObject(model)
                .preferredColorScheme(model.selectedTheme.colorScheme)
                .frame(width: 560, height: 520)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "DeepSeek 设置"
        window.setContentSize(NSSize(width: 580, height: 560))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()
        window.appearance = model.selectedTheme.nsAppearance
        self.window = window
        activate(window)

        // 监听主题变化
        cancellable = model.$selectedTheme
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak window] theme in
                window?.appearance = theme.nsAppearance
            }
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
