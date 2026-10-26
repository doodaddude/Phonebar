import AppKit
import Combine
import SwiftUI

/// NSWindow that handles standard shortcuts even though the app has no standard menu bar.
final class PhoneNSWindow: NSWindow {
    var shortcutHandler: ((String) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .command, let key = event.charactersIgnoringModifiers?.lowercased() else { return false }
        switch key {
        case "w": performClose(nil); return true
        case "q": NSApp.terminate(nil); return true
        case "c": return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
        case "x": return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
        case "v": return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
        case "a": return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
        case "z": return NSApp.sendAction(Selector(("undo:")), to: nil, from: self)
        default: return shortcutHandler?(key) ?? false
        }
    }
}

/// Owns one phone-sized window and its web session.
@MainActor
final class PhoneWindowController: NSObject, NSWindowDelegate {
    var config: WebAppConfig
    let appID: String
    let instanceID: String
    let instanceNumber: Int
    private let window: PhoneNSWindow
    let model: WebViewModel
    private var pinSubscription: AnyCancellable?
    private var opacitySubscription: AnyCancellable?
    private var ghostSubscription: AnyCancellable?
    private var onClose: ((String) -> Void)?
    private var onFocus: ((WebAppConfig) -> Void)?
    private var onConfigUpdate: ((WebAppConfig) -> Void)?
    private var onOpenInBrowser: ((WebAppConfig) -> Void)?
    var onNewInstance: ((WebAppConfig) -> Void)?

    init(config: WebAppConfig,
         instanceID: String? = nil,
         instanceNumber: Int = 1,
         cascadeIndex: Int = 0,
         spoofingEnabled: Bool = false,
         spoofedLocation: SpoofedLocation? = nil,
         onFocus: @escaping (WebAppConfig) -> Void,
         onConfigUpdate: @escaping (WebAppConfig) -> Void,
         onOpenInBrowser: @escaping (WebAppConfig) -> Void,
         onNewInstance: ((WebAppConfig) -> Void)? = nil,
         onClose: @escaping (String) -> Void) {
        self.config = config
        self.appID = config.id
        self.instanceID = instanceID ?? "\(config.id)#\(instanceNumber)"
        self.instanceNumber = instanceNumber
        self.onFocus = onFocus
        self.onConfigUpdate = onConfigUpdate
        self.onOpenInBrowser = onOpenInBrowser
        self.onNewInstance = onNewInstance
        self.onClose = onClose
        self.model = WebViewModel(config: config, spoofingEnabled: spoofingEnabled, spoofedLocation: spoofedLocation)

        let initialSize = Self.fittedSize(for: config.devicePreset)
        window = PhoneNSWindow(contentRect: NSRect(origin: .zero, size: initialSize),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                               backing: .buffered,
                               defer: false)
        super.init()

        window.title = "\(config.name)\(instanceNumber > 1 ? " (\(instanceNumber))" : "")"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.contentMinSize = NSSize(width: 280, height: 380)
        window.shortcutHandler = { [weak self] key in self?.handleShortcut(key) ?? false }

        // Hide standard macOS titlebar buttons so they don't hover above our grabber bar
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // Allow the entire window background (including our custom bars) to act as a drag region.
        // WindowDragNSView hits only cover areas where the NSView is laid out; this ensures the
        // full bar is draggable for the parts we may miss with SwiftUI layout.
        window.isMovableByWindowBackground = true

        let host = NSHostingView(rootView: PhoneWebContainer(
            model: model,
            onDeviceChange: { [weak self] device in
                self?.switchDevice(to: device)
            },
            onNewInstance: { [weak self] in
                guard let self = self else { return }
                self.onNewInstance?(self.config)
            },
            onOpenInBrowser: { [weak self] in
                guard let self = self else { return }
                self.onOpenInBrowser?(self.config)
            },
            onCloseWindow: { [weak self] in
                self?.close()
            },
            onMiniaturizeWindow: { [weak self] in
                self?.minimizeToMenuBar()
            },
            onZoomWindow: { [weak self] in
                self?.toggleZoom()
            }
        ))
        host.sizingOptions = []
        window.contentView = host
        window.setContentSize(initialSize)

        // Initial setup
        pinSubscription = model.$isPinned.sink { [weak window] pinned in
            window?.level = pinned ? .floating : .normal
        }

        opacitySubscription = model.$windowOpacity.sink { [weak window] opacity in
            window?.alphaValue = CGFloat(opacity)
        }

        ghostSubscription = model.$isGhostMode.sink { [weak window] ghost in
            window?.ignoresMouseEvents = ghost
        }
    }

    var hasUserCustomPosition = false
    private var isProgrammaticMove = false

    func positionUnderneathStatusItem(_ statusItem: NSStatusItem?) {
        guard !hasUserCustomPosition else { return }

        // Determine target screen based on user preference
        let targetDisplayPref = UserDefaults.standard.string(forKey: "PhoneBar.targetDisplay") ?? "cursor"
        let screen: NSScreen = {
            if targetDisplayPref == "main" {
                return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
            } else if targetDisplayPref == "cursor" {
                let mouseLocation = NSEvent.mouseLocation
                if let cursorScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
                    return cursorScreen
                }
            } else if targetDisplayPref.hasPrefix("screen_"),
                      let idx = Int(targetDisplayPref.dropFirst(7)),
                      idx < NSScreen.screens.count {
                return NSScreen.screens[idx]
            }
            return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        }()

        let visible = screen.visibleFrame
        let size = Self.fittedSize(for: config.devicePreset)

        let remember = UserDefaults.standard.object(forKey: "PhoneBar.rememberWindowPosition") as? Bool ?? true
        let spawnMode = UserDefaults.standard.string(forKey: "PhoneBar.windowSpawnLocation") ?? "underIcon"

        // 1. If rememberWindowPosition is on, try restoring saved origin for this app
        if remember, let saved = UserDefaults.standard.string(forKey: "PhoneBar.lastOrigin.\(config.id)") {
            let point = NSPointFromString(saved)
            // Clamp fully — origin must be valid AND the window must fit entirely on screen.
            if point.x > visible.minX && point.y > visible.minY &&
               point.x + size.width < visible.maxX && point.y + size.height < visible.maxY {
                let clampedX = max(visible.minX + 4, min(visible.maxX - size.width - 4, point.x))
                let clampedY = max(visible.minY + 4, min(visible.maxY - size.height - 4, point.y))
                isProgrammaticMove = true
                window.setFrame(NSRect(origin: NSPoint(x: clampedX, y: clampedY), size: size), display: true)
                isProgrammaticMove = false
                hasUserCustomPosition = true
                return
            }
        }

        // 2. Custom spawn modes
        if spawnMode == "center" {
            let targetX = visible.midX - (size.width / 2.0)
            let targetY = visible.midY - (size.height / 2.0)
            isProgrammaticMove = true
            window.setFrame(NSRect(x: targetX, y: targetY, width: size.width, height: size.height), display: true)
            isProgrammaticMove = false
            return
        } else if spawnMode == "topLeft" {
            let targetX = visible.minX + 24
            let targetY = visible.maxY - size.height - 24
            isProgrammaticMove = true
            window.setFrame(NSRect(x: targetX, y: targetY, width: size.width, height: size.height), display: true)
            isProgrammaticMove = false
            return
        } else if spawnMode == "topRight" {
            let targetX = visible.maxX - size.width - 24
            let targetY = visible.maxY - size.height - 24
            isProgrammaticMove = true
            window.setFrame(NSRect(x: targetX, y: targetY, width: size.width, height: size.height), display: true)
            isProgrammaticMove = false
            return
        }

        // 3. Default: Centered directly underneath companion menu bar icon
        if let button = statusItem?.button, let buttonWindow = button.window {
            let buttonScreenRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            let centerX = buttonScreenRect.midX
            let menuBottomY = buttonScreenRect.minY

            var targetX = centerX - (size.width / 2.0)
            targetX = max(visible.minX + 8, min(visible.maxX - size.width - 8, targetX))
            let targetY = menuBottomY - size.height - 2

            isProgrammaticMove = true
            window.setFrame(NSRect(x: targetX, y: targetY, width: size.width, height: size.height), display: true)
            isProgrammaticMove = false
            return
        }

        // Fallback under menu bar
        let y = visible.maxY - size.height - 2
        let x = max(visible.minX + 16, visible.maxX - size.width - 24)
        isProgrammaticMove = true
        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        isProgrammaticMove = false
    }

    func positionUnderneathMenuBar(index: Int = 0) {
        guard !hasUserCustomPosition else { return }
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = Self.fittedSize(for: config.devicePreset)

        // Pinned directly below menu bar
        let y = visible.maxY - size.height - 2

        // Aligned towards right side under menu bar, slightly stepped if multiple windows
        let margin: CGFloat = 20
        let step = CGFloat(index % 4) * 32
        let x = max(visible.minX + margin, visible.maxX - size.width - margin - step)

        isProgrammaticMove = true
        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        isProgrammaticMove = false
    }

    func switchDevice(to device: DevicePreset) {
        config.devicePreset = device
        model.updateDevice(device)

        let targetSize = Self.fittedSize(for: device)
        var frame = window.frame
        let topY = frame.maxY // keep pinned underneath the menu bar
        frame.size = targetSize
        frame.origin.y = topY - targetSize.height

        window.setFrame(frame, display: true, animate: true)
        onConfigUpdate?(config)
    }

    func toggleZoom() {
        if config.devicePreset == .iPhone16ProMax || config.devicePreset == .desktopMac {
            switchDevice(to: .iPhoneMini)
        } else {
            switchDevice(to: .iPhone16ProMax)
        }
    }

    func show() {
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)

        let targetFrame = window.frame
        guard let screen = window.screen ?? NSScreen.main else {
            window.makeKeyAndOrderFront(nil)
            return
        }

        if !window.isVisible || window.alphaValue < 0.1 {
            let startWidth: CGFloat = 36
            let startHeight: CGFloat = 8
            let startX = targetFrame.midX - (startWidth / 2)
            let startY = screen.visibleFrame.maxY - startHeight

            window.setFrame(NSRect(x: startX, y: startY, width: startWidth, height: startHeight), display: false)
            window.alphaValue = 0.05
            window.makeKeyAndOrderFront(nil)

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.28
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                window.animator().setFrame(targetFrame, display: true)
                window.animator().alphaValue = 1.0
            }
        } else {
            window.makeKeyAndOrderFront(nil)
        }

        onFocus?(config)
    }

    func minimizeToMenuBar() {
        guard let screen = window.screen ?? NSScreen.main else {
            window.miniaturize(nil)
            return
        }
        let currentFrame = window.frame
        let shrinkWidth: CGFloat = 36
        let shrinkHeight: CGFloat = 8
        let shrinkX = currentFrame.midX - (shrinkWidth / 2)
        let shrinkY = screen.visibleFrame.maxY - shrinkHeight
        let shrinkFrame = NSRect(x: shrinkX, y: shrinkY, width: shrinkWidth, height: shrinkHeight)

        // Guard against windowDidMove saving the mid-animation frame (near top of screen)
        // as the "last user origin". Without this flag the shrink animation fires windowDidMove
        // and writes {midX - 18, maxY - 8} to UserDefaults, causing the bottom-left spawn bug.
        isProgrammaticMove = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1.0)
            window.animator().setFrame(shrinkFrame, display: true)
            window.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isProgrammaticMove = false
                self.window.orderOut(nil)
                self.window.setFrame(currentFrame, display: false)
            }
        })
    }

    func toggleVisibility() {
        if window.isVisible && window.alphaValue > 0.8 && !window.isMiniaturized {
            minimizeToMenuBar()
        } else {
            show()
        }
    }

    func close() { window.close() }

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        onFocus?(config)
    }

    func windowDidMove(_ notification: Notification) {
        if !isProgrammaticMove {
            hasUserCustomPosition = true
            let remember = UserDefaults.standard.object(forKey: "PhoneBar.rememberWindowPosition") as? Bool ?? true
            if remember {
                UserDefaults.standard.set(NSStringFromPoint(window.frame.origin), forKey: "PhoneBar.lastOrigin.\(config.id)")
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        pinSubscription = nil
        opacitySubscription = nil
        ghostSubscription = nil
        model.teardown()
        window.contentView = nil
        let id = instanceID
        let callback = onClose
        onClose = nil
        Task { @MainActor in callback?(id) }
    }

    // MARK: - Helpers

    private func handleShortcut(_ key: String) -> Bool {
        switch key {
        case "r": model.webView.reload(); return true
        case "[": model.webView.goBack(); return true
        case "]": model.webView.goForward(); return true
        default: return false
        }
    }

    static func fittedSize(for device: DevicePreset) -> NSSize {
        let dims = device.dimensions
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let maxHeight = screen.height - 10
        let maxWidth = screen.width - 20
        return NSSize(width: min(dims.width, maxWidth), height: min(dims.height, maxHeight))
    }
}
