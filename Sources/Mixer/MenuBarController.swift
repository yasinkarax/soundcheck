import AppKit
import Combine
import SwiftUI

@available(macOS 14.2, *)
final class MixerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@available(macOS 14.2, *)
final class TransparentMixerHostingView: NSHostingView<MixerView> {
    override var isOpaque: Bool { false }
}

/// Owns the panel so AppKit does not add a second popover surface around the design.
@available(macOS 14.2, *)
@MainActor
final class MenuBarController: NSObject {
    private let model: MixerModel
    private let statusItem: NSStatusItem
    private let panel: MixerPanel
    private let hostingView: TransparentMixerHostingView
    private var subscriptions = Set<AnyCancellable>()
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var layoutScheduled = false
    private var activationObserver: NSObjectProtocol?

    init(model: MixerModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        hostingView = TransparentMixerHostingView(rootView: MixerView(model: model))
        panel = MixerPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .none
        panel.title = "Soundcheck"
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView

        if let button = statusItem.button {
            button.image = Self.statusImage()
            button.imagePosition = .imageOnly
            button.toolTip = "Soundcheck"
            button.setAccessibilityLabel("Soundcheck")
            button.target = self
            button.action = #selector(togglePanel)
        }

        model.$apps.map { $0.count }.removeDuplicates()
            .combineLatest(model.$error.removeDuplicates(), model.$enabled.removeDuplicates())
            .sink { [weak self] _ in self?.scheduleLayout() }
            .store(in: &subscriptions)

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      application.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
                self?.hidePanel()
            }
        }
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(nil)
        installEventMonitors()
    }

    func shutdown() {
        hidePanel()
        subscriptions.removeAll()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        activationObserver = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func hidePanel() {
        model.showingOutput = false
        panel.orderOut(nil)
        removeEventMonitors()
    }

    private func scheduleLayout() {
        guard !layoutScheduled else { return }
        layoutScheduled = true
        // Published values are emitted before mutation. Measure after the model updates.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.layoutScheduled = false
            self.positionPanel()
        }
    }

    private func positionPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        hostingView.layoutSubtreeIfNeeded()
        let fittingSize = hostingView.fittingSize
        guard fittingSize.width > 0, fittingSize.height > 0 else { return }

        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 8
        let size = NSSize(
            width: min(ceil(fittingSize.width), visible.width - margin * 2),
            height: min(ceil(fittingSize.height), visible.height - margin * 2)
        )
        let maxX = max(visible.minX + margin, visible.maxX - size.width - margin)
        let maxY = max(visible.minY + margin, visible.maxY - size.height - margin)
        let origin = NSPoint(
            x: min(max(anchor.midX - size.width / 2, visible.minX + margin), maxX),
            y: min(max(anchor.minY - size.height - margin, visible.minY + margin), maxY)
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: panel.isVisible)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        panel.invalidateShadow()
    }

    private func installEventMonitors() {
        removeEventMonitors()
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
        ) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self, self.panel.isVisible else { return false }
                if event.type == .keyDown {
                    if event.keyCode == 53 {
                        self.hidePanel()
                        return true
                    }
                    return false
                }
                if !self.containsInteraction(event) { self.hidePanel() }
                return false
            }
            return consumed ? nil : event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.hidePanel() }
        }
    }

    private func containsInteraction(_ event: NSEvent) -> Bool {
        if event.window === panel || panel.frame.contains(NSEvent.mouseLocation) { return true }
        if let button = statusItem.button, let window = button.window {
            let statusFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
            if statusFrame.contains(NSEvent.mouseLocation) { return true }
        }
        var parent = event.window?.parent
        while let window = parent {
            if window === panel { return true }
            parent = window.parent
        }
        // Native menus and the output popover belong to the mixer interaction.
        if let window = event.window,
           window.isVisible,
           window is NSPanel || window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue {
            return true
        }
        return false
    }

    private func removeEventMonitors() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
    }

    private static func statusImage() -> NSImage? {
        let renderer = ImageRenderer(content: BrandLogoMark(width: 18).frame(width: 18, height: 18))
        renderer.proposedSize = ProposedViewSize(width: 18, height: 18)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = false
        return image
    }
}

@available(macOS 14.2, *)
@MainActor
final class SoundcheckAppDelegate: NSObject, NSApplicationDelegate {
    private var model: MixerModel?
    private var controller: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let model = MixerModel(preview: CommandLine.arguments.contains("--preview-ui"))
        self.model = model
        controller = MenuBarController(model: model)
        if CommandLine.arguments.contains("--preview-ui") {
            DispatchQueue.main.async { [weak self] in self?.controller?.showPanel() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
        model?.disable()
    }

}
