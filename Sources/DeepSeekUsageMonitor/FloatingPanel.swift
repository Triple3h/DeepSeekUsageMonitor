import AppKit

final class FloatingPanel: NSPanel {
    init(contentViewController: NSViewController, contentSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.contentViewController = contentViewController
        self.setContentSize(contentSize)

        // 三层圆角裁剪，确保毛玻璃效果下圆角正确显示
        self.contentViewController?.view.wantsLayer = true
        self.contentViewController?.view.layer?.cornerRadius = Theme.panelCornerRadius
        self.contentViewController?.view.layer?.masksToBounds = true
        self.contentView?.wantsLayer = true
        self.contentView?.layer?.cornerRadius = Theme.panelCornerRadius
        self.contentView?.layer?.masksToBounds = true
        self.contentView?.superview?.wantsLayer = true
        self.contentView?.superview?.layer?.cornerRadius = Theme.panelCornerRadius

        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
