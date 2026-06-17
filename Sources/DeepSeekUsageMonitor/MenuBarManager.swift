import AppKit
import Combine
import SwiftUI

// MARK: - Menu Bar Manager

@MainActor
final class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var monitor: Any?
    private var autoCloseTimer: Timer?
    private var hoverStateTimer: Timer?
    private var isMouseInsidePanel = false
    private var lastStatusButtonScreenFrame: NSRect?
    private var cancellables = Set<AnyCancellable>()

    let model = AppModel()
    private var hostingController: NSHostingController<AnyView>!

    // MARK: - Init

    override init() {
        super.init()
        setupStatusItem()
        setupPanel()
        observeModel()
        startAutoRefresh()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        updateStatusBarButton(button)
        button.action = #selector(togglePanel)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }

        // 右键或 Ctrl+左键 → 显示系统菜单
        if NSApp.currentEvent?.type == .rightMouseUp ||
            NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            return
        }

        if panel.isVisible {
            closePanel()
        } else {
            showPanel(button: button)
        }
    }

    // MARK: - Panel

    private func setupPanel() {
        hostingController = NSHostingController(
            rootView: AnyView(
                DashboardView(onClose: { [weak self] in self?.closePanel() })
                    .environmentObject(model)
                    .preferredColorScheme(model.selectedTheme.colorScheme)
                    .frame(width: Theme.panelWidth)
            )
        )

        panel = FloatingPanel(
            contentViewController: hostingController,
            contentSize: NSSize(width: Theme.panelWidth, height: Theme.panelDashboardHeight)
        )
        panel.appearance = model.selectedTheme.nsAppearance
    }

    func showPanel(button: NSStatusBarButton) {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        if let screen = button.window?.screen ?? NSScreen.main {
            resizePanelToMatchContent(keepingTopEdge: false)
            let buttonRect = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero
            lastStatusButtonScreenFrame = buttonRect

            var origin = NSPoint(
                x: buttonRect.midX - panel.frame.width / 2,
                y: buttonRect.minY - panel.frame.height - Theme.panelTopGap
            )

            // 确保面板不超出屏幕
            if origin.x < screen.visibleFrame.minX + 4 {
                origin.x = screen.visibleFrame.minX + 4
            }
            if origin.x + panel.frame.width > screen.visibleFrame.maxX - 4 {
                origin.x = screen.visibleFrame.maxX - panel.frame.width - 4
            }

            panel.setFrameOrigin(origin)
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        startHoverStateMonitoring()
        refreshHoverState()
        schedulePanelAutoClose()

        // 点击面板外部时关闭
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    func closePanel() {
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil
        hoverStateTimer?.invalidate()
        hoverStateTimer = nil
        isMouseInsidePanel = false
        panel.orderOut(nil)
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    // MARK: - Auto Close

    private func schedulePanelAutoClose() {
        autoCloseTimer?.invalidate()
        guard panel.isVisible, !isMouseInsidePanel else { return }
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.closePanel()
            }
        }
    }

    private func startHoverStateMonitoring() {
        hoverStateTimer?.invalidate()
        hoverStateTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshHoverState()
            }
        }
    }

    private func refreshHoverState() {
        guard panel.isVisible else { return }

        let mouseLocation = NSEvent.mouseLocation
        let wasInside = isMouseInsidePanel

        isMouseInsidePanel = panel.frame.contains(mouseLocation)

        // hover 状态变化时控制自动关闭
        if isMouseInsidePanel {
            autoCloseTimer?.invalidate()
            autoCloseTimer = nil
        } else if wasInside != isMouseInsidePanel {
            schedulePanelAutoClose()
        }
    }

    // MARK: - Model Observation

    private func observeModel() {
        model.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshStatusBarText()
                Task { @MainActor [weak self] in
                    self?.resizePanelToMatchContent(keepingTopEdge: true)
                }
            }
            .store(in: &cancellables)

        // 面板内容切换：Dashboard ↔ Settings
        model.$isSettingsShown
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSettings in
                self?.switchPanelContent(toSettings: isSettings)
            }
            .store(in: &cancellables)

        // 主题切换
        model.$selectedTheme
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme in
                self?.applyTheme(theme)
            }
            .store(in: &cancellables)
    }

    private func switchPanelContent(toSettings: Bool) {
        let newRoot: AnyView = toSettings
            ? AnyView(SettingsView().environmentObject(model).frame(width: Theme.panelWidth).preferredColorScheme(model.selectedTheme.colorScheme))
            : AnyView(DashboardView(onClose: { [weak self] in self?.closePanel() }).environmentObject(model).frame(width: Theme.panelWidth).preferredColorScheme(model.selectedTheme.colorScheme))

        hostingController.rootView = newRoot

        let newHeight = toSettings ? Theme.panelSettingsHeight : (model.userSummary != nil ? Theme.panelDashboardHeight : Theme.panelEmptyHeight)
        let newSize = NSSize(width: Theme.panelWidth, height: newHeight)
        let oldFrame = panel.frame
        let newOrigin = NSPoint(x: oldFrame.origin.x, y: oldFrame.maxY - newHeight)
        panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true, animate: true)
    }

    private func refreshStatusBarText() {
        guard let button = statusItem.button else { return }
        updateStatusBarButton(button)
    }

    // MARK: - Menu Bar Icon

    private var menuBarIcon: NSImage? {
        guard let image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "AI 用量监控") else {
            return nil
        }
        image.isTemplate = true
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        return image.withSymbolConfiguration(config)
    }

    private func updateStatusBarButton(_ button: NSStatusBarButton) {
        if model.isAnyBalanceWarning {
            if let warningImage = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil) {
                warningImage.isTemplate = false
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
                button.image = warningImage.withSymbolConfiguration(config)
            }
            button.title = menuBarBalanceText
            button.imagePosition = .imageLeading
            button.contentTintColor = .systemRed
        } else {
            button.image = menuBarIcon
            button.title = menuBarBalanceText
            button.imagePosition = .imageLeading
            button.contentTintColor = nil
        }
    }

    private var menuBarBalanceText: String {
        let dsActive = model.deepSeekEnabled
        let mimoActive = model.mimoEnabled

        // 双平台：分别展示各自余额
        if dsActive && mimoActive {
            let dsPart: String?
            if let s = model.userSummary {
                dsPart = "DS \(currencySymbol(s.primaryCurrency))\(money(s.totalBalance))"
            } else { dsPart = nil }

            let mimoPart = mimoMenuBarText

            if let dsPart, let mimoPart { return " \(dsPart) | \(mimoPart)" }
            if let dsPart { return " \(dsPart) | MIMO" }
            if let mimoPart { return " DS | \(mimoPart)" }
            return " DS | MIMO"
        }

        // 仅 DeepSeek
        if dsActive {
            guard let s = model.userSummary else { return " DeepSeek" }
            return " \(currencySymbol(s.primaryCurrency))\(money(s.totalBalance))"
        }

        // 仅 Mimo
        if mimoActive {
            guard let part = mimoMenuBarText else { return " Mimo" }
            return " \(part)"
        }

        return " AI Monitor"
    }

    /// Mimo 平台菜单栏展示文本（按计费模式决定展示余额还是 Token 剩余）
    private var mimoMenuBarText: String? {
        if model.mimoBillingMode == .tokenPlan {
            if let usage = model.mimoTokenPlanUsage {
                let remainingPercent = Int((100 - usage.usagePercent).rounded())
                return "MIMO \(remainingPercent)%"
            }
            return nil
        } else {
            if let b = model.mimoBalance {
                return "MIMO \(currencySymbol(b.currency))\(money(b.availableBalance))"
            }
            return nil
        }
    }

    private func currencySymbol(_ currency: String) -> String {
        currency.uppercased() == "CNY" ? "¥" : "\(currency) "
    }

    private func money(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        return String(format: "%.2f", number.doubleValue)
    }

    private func compactNumber(_ value: Int) -> String {
        if value >= 1_000_000_000 { return String(format: "%.1fB", Double(value) / 1_000_000_000) }
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return value.formatted()
    }

    // MARK: - Panel Resize

    private func resizePanelToMatchContent(keepingTopEdge: Bool) {
        guard panel != nil else { return }
        let newHeight: CGFloat = model.isSettingsShown
            ? Theme.panelSettingsHeight
            : (model.userSummary != nil ? Theme.panelDashboardHeight : Theme.panelEmptyHeight)
        let newSize = NSSize(width: Theme.panelWidth, height: newHeight)
        guard panel.frame.size != newSize else { return }

        let oldFrame = panel.frame
        var newOrigin = oldFrame.origin
        if keepingTopEdge {
            newOrigin.y = oldFrame.maxY - newSize.height
        }

        panel.setFrame(NSRect(origin: newOrigin, size: newSize), display: true, animate: panel.isVisible)
    }

    // MARK: - Actions

    func startAutoRefresh() {
        model.startBackgroundRefresh()
    }

    func stopAutoRefresh() {
        model.stopBackgroundRefresh()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func cleanup() {
        stopAutoRefresh()
        closePanel()
        if let monitor = monitor { NSEvent.removeMonitor(monitor) }
        cancellables.removeAll()
        if let button = statusItem.button {
            button.action = nil
            button.target = nil
        }
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Theme

    private func applyTheme(_ theme: AppThemeMode) {
        panel.appearance = theme.nsAppearance
        // 重新应用 SwiftUI 视图以更新 preferredColorScheme
        switchPanelContent(toSettings: model.isSettingsShown)
    }
}
