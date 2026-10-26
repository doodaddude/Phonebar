import AppKit
import SwiftUI
import Combine

// MARK: - Bubble Model

enum BubbleKind: Equatable {
    case launcher
    case openApp(instanceID: String)
    case suggestedOrRecent(config: WebAppConfig)
}

struct BubbleEntry: Identifiable, Equatable {
    let id: String
    let appID: String
    let appName: String
    var symbolName: String = "globe"
    var config: WebAppConfig? = nil
    var favicon: NSImage?
    let kind: BubbleKind

    static func == (lhs: BubbleEntry, rhs: BubbleEntry) -> Bool {
        lhs.id == rhs.id && lhs.appID == rhs.appID && lhs.kind == rhs.kind
    }
}

// MARK: - Hub Edge

enum HubEdge { case left, right, top, bottom }

// MARK: - BubbleHubState

@MainActor
final class BubbleHubState: ObservableObject {
    @Published var launcherEntry: BubbleEntry = BubbleEntry(
        id: "launcher",
        appID: "launcher",
        appName: "PhoneBar Hub",
        favicon: nil,
        kind: .launcher
    )
    @Published var topEntries: [BubbleEntry] = []       // Sprouting up (suggested / recent)
    @Published var bottomEntries: [BubbleEntry] = []    // Sprouting down (open running apps)

    @Published var isSprouted: Bool = false
    @Published var dockedEdge: HubEdge = .right
    @Published var isHovering: Bool = false
    @Published var isDragging: Bool = false
}

// MARK: - BubbleHubController

@MainActor
final class BubbleHubController: NSObject {

    // ── Constants ──────────────────────────────────────────────────────────
    static let diameter:    CGFloat = 52
    static let peekAmount:  CGFloat = 36   // Keep a generous 36pt tab visible even when peeking
    static let spacing:     CGFloat = 8

    // ── Owned objects ──────────────────────────────────────────────────────
    let state = BubbleHubState()
    private var panel: NSPanel?
    private weak var windowManager: WindowManager?
    private weak var store: AppStore?

    private var instancesSub: AnyCancellable?
    private var recentsSub: AnyCancellable?
    private var appsSub: AnyCancellable?

    private var hasCustomPosition = false
    private var launcherCenter: CGPoint?

    // ── Init ───────────────────────────────────────────────────────────────

    init(windowManager: WindowManager, store: AppStore? = nil) {
        self.windowManager = windowManager
        self.store = store
        super.init()

        // Sync open running apps
        instancesSub = windowManager.$instances
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshEntries()
            }

        // Sync store changes (recents, suggestions)
        if let store = store {
            recentsSub = store.$recentlyOpenedIDs
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.refreshEntries()
                }

            appsSub = store.$apps
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.refreshEntries()
                }
        }

        refreshEntries()
    }

    func attachStore(_ store: AppStore) {
        self.store = store
        recentsSub = store.$recentlyOpenedIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshEntries()
            }
        appsSub = store.$apps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshEntries()
            }
        refreshEntries()
    }

    // ── Public API ─────────────────────────────────────────────────────────

    func show() {
        if panel == nil { buildPanel() }
        guard let panel = panel else { return }
        updatePanelSize()
        snapToEdge(animated: false)
        panel.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }

    var isVisible: Bool { panel?.isVisible ?? false }

    // ── Panel build ────────────────────────────────────────────────────────

    private func buildPanel() {
        let sz = currentPanelSize()
        let screen = NSScreen.main ?? NSScreen.screens.first
        let sf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        // Initial frame: Docked cleanly on the right screen edge
        let initialOrigin = NSPoint(x: sf.maxX - sz.width, y: sf.midY - sz.height / 2)

        let p = NSPanel(
            contentRect: NSRect(origin: initialOrigin, size: sz),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.ignoresMouseEvents = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let content = BubbleHubRootView(state: state, controller: self)
        let host = NSHostingView(rootView: content)
        host.sizingOptions = []
        p.contentView = host

        self.panel = p
    }

    // ── Sizing ─────────────────────────────────────────────────────────────

    func currentPanelSize() -> CGSize {
        let d = Self.diameter
        let sp = Self.spacing

        let topCount = state.isSprouted ? state.topEntries.count : 0
        let bottomCount = state.isSprouted ? state.bottomEntries.count : 0
        let totalCount = 1 + topCount + bottomCount

        switch state.dockedEdge {
        case .left, .right:
            let h = CGFloat(totalCount) * (d + sp) - sp + 20
            return CGSize(width: d + 20, height: h)
        case .top, .bottom:
            let w = CGFloat(totalCount) * (d + sp) - sp + 20
            return CGSize(width: w, height: d + 20)
        }
    }

    // Calculate the launcher bubble's center point in AppKit screen coordinates given panel origin & size
    func launcherCenterPoint(forPanelOrigin origin: CGPoint, size: CGSize) -> CGPoint {
        let d = Self.diameter
        let sp = Self.spacing
        let bottomCount = state.isSprouted ? state.bottomEntries.count : 0
        let topCount = state.isSprouted ? state.topEntries.count : 0

        switch state.dockedEdge {
        case .left, .right:
            let launcherOffsetY = 10 + CGFloat(bottomCount) * (d + sp) + d / 2
            return CGPoint(x: origin.x + size.width / 2, y: origin.y + launcherOffsetY)
        case .top, .bottom:
            let launcherOffsetX = 10 + CGFloat(topCount) * (d + sp) + d / 2
            return CGPoint(x: origin.x + launcherOffsetX, y: origin.y + size.height / 2)
        }
    }

    func updatePanelSize() {
        guard let panel = panel else { return }
        let newSize = currentPanelSize()
        let oldFrame = panel.frame

        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        let sf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let d = Self.diameter
        let sp = Self.spacing
        let bottomCount = state.isSprouted ? state.bottomEntries.count : 0
        let topCount = state.isSprouted ? state.topEntries.count : 0

        // Fallback launcher center if not yet cached
        let currentLauncherCenter = launcherCenter ?? launcherCenterPoint(forPanelOrigin: oldFrame.origin, size: oldFrame.size)

        var newX = oldFrame.origin.x
        var newY = oldFrame.origin.y

        switch state.dockedEdge {
        case .left, .right:
            // Launcher's Y position in panel is: 10 + bottomCount * (d + sp) + d/2
            let launcherOffsetY = 10 + CGFloat(bottomCount) * (d + sp) + d / 2
            let targetOriginY = currentLauncherCenter.y - launcherOffsetY
            newY = max(sf.minY + 8, min(sf.maxY - newSize.height - 8, targetOriginY))
            // Keep X docked cleanly against the edge
            let peek = Self.peekAmount
            let expand = state.isHovering || state.isSprouted
            if state.dockedEdge == .left {
                newX = sf.minX - newSize.width + (expand ? newSize.width : peek)
            } else {
                newX = sf.maxX - (expand ? newSize.width : peek)
            }
        case .top, .bottom:
            let launcherOffsetX = 10 + CGFloat(topCount) * (d + sp) + d / 2
            let targetOriginX = currentLauncherCenter.x - launcherOffsetX
            newX = max(sf.minX + 8, min(sf.maxX - newSize.width - 8, targetOriginX))
            let peek = Self.peekAmount
            let expand = state.isHovering || state.isSprouted
            if state.dockedEdge == .top {
                newY = sf.maxY - (expand ? newSize.height : peek)
            } else {
                newY = sf.minY - newSize.height + (expand ? newSize.height : peek)
            }
        }

        panel.setFrame(NSRect(x: newX, y: newY, width: newSize.width, height: newSize.height), display: true)
        // Refresh launcherCenter to the exact actual clamped location
        launcherCenter = launcherCenterPoint(forPanelOrigin: CGPoint(x: newX, y: newY), size: newSize)
    }

    // ── Edge snap ─────────────────────────────────────────────────────────

    func snapToEdge(animated: Bool = true) {
        guard let panel = panel else { return }
        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen = screen else { return }

        let sf  = screen.visibleFrame
        let fr  = panel.frame
        let sz  = currentPanelSize()
        let peek = Self.peekAmount
        let expand = state.isHovering || state.isSprouted

        let d = Self.diameter
        let sp = Self.spacing
        let bottomCount = state.isSprouted ? state.bottomEntries.count : 0
        let topCount = state.isSprouted ? state.topEntries.count : 0

        // Get the active launcher center
        let currentLauncherCenter = launcherCenter ?? launcherCenterPoint(forPanelOrigin: fr.origin, size: fr.size)

        let edge: HubEdge
        if !hasCustomPosition {
            edge = .right
        } else {
            // Apply a 35pt hysteresis bias to the currently docked edge to eliminate cursor fighting/jitter
            let bias: CGFloat = 35.0
            var dLeft   = currentLauncherCenter.x - sf.minX
            var dRight  = sf.maxX - currentLauncherCenter.x
            var dTop    = sf.maxY - currentLauncherCenter.y
            var dBottom = currentLauncherCenter.y - sf.minY

            switch state.dockedEdge {
            case .left:   dLeft -= bias
            case .right:  dRight -= bias
            case .top:    dTop -= bias
            case .bottom: dBottom -= bias
            }

            let minD = min(dLeft, dRight, dTop, dBottom)
            switch minD {
            case dLeft:   edge = .left
            case dRight:  edge = .right
            case dTop:    edge = .top
            default:      edge = .bottom
            }
        }
        state.dockedEdge = edge

        var target: NSPoint
        switch edge {
        case .left:
            let launcherOffsetY = 10 + CGFloat(bottomCount) * (d + sp) + d / 2
            let cy = max(sf.minY + 8, min(sf.maxY - sz.height - 8, currentLauncherCenter.y - launcherOffsetY))
            target = NSPoint(x: sf.minX - sz.width + (expand ? sz.width : peek), y: cy)
        case .right:
            let launcherOffsetY = 10 + CGFloat(bottomCount) * (d + sp) + d / 2
            let cy = max(sf.minY + 8, min(sf.maxY - sz.height - 8, currentLauncherCenter.y - launcherOffsetY))
            target = NSPoint(x: sf.maxX - (expand ? sz.width : peek), y: cy)
        case .top:
            let launcherOffsetX = 10 + CGFloat(topCount) * (d + sp) + d / 2
            let cx = max(sf.minX + 8, min(sf.maxX - sz.width - 8, currentLauncherCenter.x - launcherOffsetX))
            target = NSPoint(x: cx, y: sf.maxY - (expand ? sz.height : peek))
        case .bottom:
            let launcherOffsetX = 10 + CGFloat(topCount) * (d + sp) + d / 2
            let cx = max(sf.minX + 8, min(sf.maxX - sz.width - 8, currentLauncherCenter.x - launcherOffsetX))
            target = NSPoint(x: cx, y: sf.minY - sz.height + (expand ? sz.height : peek))
        }

        let targetFrame = NSRect(origin: target, size: sz)

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.32
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }

        // Cache the launcher bubble's screen center
        launcherCenter = launcherCenterPoint(forPanelOrigin: targetFrame.origin, size: sz)
    }

    func didEndDrag() {
        hasCustomPosition = true
        if let panel = panel {
            launcherCenter = launcherCenterPoint(forPanelOrigin: panel.frame.origin, size: panel.frame.size)
        }
        snapToEdge(animated: true)
    }

    func setHovering(_ hovering: Bool) {
        guard !state.isDragging else { return }
        guard state.isHovering != hovering else { return }
        state.isHovering = hovering
        if !state.isSprouted {
            snapToEdge(animated: true)
        }
    }

    // ── Sprout Toggle ──────────────────────────────────────────────────────

    func toggleSprout() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            state.isSprouted.toggle()
        }
        refreshEntries()
        updatePanelSize()
        snapToEdge(animated: true)
    }

    // ── Entry Refresh ──────────────────────────────────────────────────────

    func refreshEntries() {
        guard let wm = windowManager else { return }

        // 1. Bottom entries: Open running app instances
        var bottom: [BubbleEntry] = []
        for inst in wm.instances {
            let cachedFav = FaviconService.shared.cachedFavicon(for: inst.app.host)
            let existing = state.bottomEntries.first(where: { $0.id == inst.id }) ?? state.topEntries.first(where: { $0.appID == inst.appID })
            let fav = existing?.favicon ?? cachedFav

            let entry = BubbleEntry(
                id: inst.id,
                appID: inst.appID,
                appName: inst.app.name,
                symbolName: inst.app.symbolName,
                config: inst.app,
                favicon: fav,
                kind: .openApp(instanceID: inst.id)
            )
            if fav == nil {
                FaviconService.shared.loadFavicon(for: inst.app) { [weak self] img in
                    guard let self = self, let img = img else { return }
                    DispatchQueue.main.async {
                        if let idx = self.state.bottomEntries.firstIndex(where: { $0.id == inst.id }) {
                            self.state.bottomEntries[idx].favicon = img
                        }
                    }
                }
            }
            bottom.append(entry)
        }
        state.bottomEntries = bottom

        // 2. Top entries: 3 Suggested / Recent apps
        // Prefer recently opened apps that are not already running; fallback to suggested apps.
        var topApps: [WebAppConfig] = []
        let runningAppIDs = Set(wm.instances.map { $0.appID })

        if let store = self.store {
            let recentsNotRunning = store.recentlyOpenedApps.filter { !runningAppIDs.contains($0.id) }
            for app in recentsNotRunning {
                if topApps.count < 3 {
                    topApps.append(app)
                }
            }

            if topApps.count < 3 {
                let chosenIDs = Set(topApps.map { $0.id }).union(runningAppIDs)
                let suggestions = store.suggestedApps.filter { !chosenIDs.contains($0.id) }
                for app in suggestions {
                    if topApps.count < 3 {
                        topApps.append(app)
                    }
                }
            }
        }

        var top: [BubbleEntry] = []
        for app in topApps {
            let cachedFav = FaviconService.shared.cachedFavicon(for: app.host)
            let existing = state.topEntries.first(where: { $0.appID == app.id }) ?? state.bottomEntries.first(where: { $0.appID == app.id })
            let fav = existing?.favicon ?? cachedFav

            let entry = BubbleEntry(
                id: app.id,
                appID: app.id,
                appName: app.name,
                symbolName: app.symbolName,
                config: app,
                favicon: fav,
                kind: .suggestedOrRecent(config: app)
            )
            if fav == nil {
                FaviconService.shared.loadFavicon(for: app) { [weak self] img in
                    guard let self = self, let img = img else { return }
                    DispatchQueue.main.async {
                        if let idx = self.state.topEntries.firstIndex(where: { $0.appID == app.id }) {
                            self.state.topEntries[idx].favicon = img
                        }
                    }
                }
            }
            top.append(entry)
        }
        state.topEntries = top

        if panel != nil && state.isSprouted {
            updatePanelSize()
        }
    }

    // ── Actions ────────────────────────────────────────────────────────────

    func singleTap(entry: BubbleEntry) {
        switch entry.kind {
        case .launcher:
            toggleSprout()

        case .openApp(let instanceID):
            windowManager?.instances.first(where: { $0.id == instanceID })?.controller.show()

        case .suggestedOrRecent(let config):
            if let store = self.store {
                windowManager?.open(config, store: store)
            }
        }
    }

    func doubleTap(entry: BubbleEntry) {
        switch entry.kind {
        case .launcher:
            toggleSprout()

        case .openApp(let instanceID):
            windowManager?.instances.first(where: { $0.id == instanceID })?.controller.toggleVisibility()

        case .suggestedOrRecent(let config):
            if let store = self.store {
                windowManager?.open(config, store: store, forceNewInstance: true)
            }
        }
    }

    func movePanel(by delta: CGPoint) {
        guard let panel = panel else { return }
        let o = panel.frame.origin
        panel.setFrameOrigin(NSPoint(x: o.x + delta.x, y: o.y + delta.y))
    }
}

// MARK: - SwiftUI Root View

struct BubbleHubRootView: View {
    @ObservedObject var state: BubbleHubState
    let controller: BubbleHubController

    var body: some View {
        Group {
            if state.dockedEdge == .left || state.dockedEdge == .right {
                // Vertical sprout:
                // [Top: Suggested/Recent 3 - going up]
                // [Center: Launcher Bubble]
                // [Bottom: Open Apps - going down]
                VStack(spacing: BubbleHubController.spacing) {
                    if state.isSprouted {
                        // Display top entries (first at very top, going downwards to launcher)
                        ForEach(state.topEntries) { entry in
                            BubbleItemView(entry: entry, controller: controller, badge: "✦")
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    // The Core Launcher Bubble
                    BubbleItemView(
                        entry: state.launcherEntry,
                        controller: controller,
                        isLauncher: true,
                        isSprouted: state.isSprouted
                    )

                    if state.isSprouted {
                        // Display open running instances sprouting downwards
                        ForEach(state.bottomEntries) { entry in
                            BubbleItemView(entry: entry, controller: controller, badge: "●")
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            } else {
                // Horizontal sprout:
                // [Left: Suggested/Recent] [Center: Launcher] [Right: Open Apps]
                HStack(spacing: BubbleHubController.spacing) {
                    if state.isSprouted {
                        ForEach(state.topEntries) { entry in
                            BubbleItemView(entry: entry, controller: controller, badge: "✦")
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    BubbleItemView(
                        entry: state.launcherEntry,
                        controller: controller,
                        isLauncher: true,
                        isSprouted: state.isSprouted
                    )

                    if state.isSprouted {
                        ForEach(state.bottomEntries) { entry in
                            BubbleItemView(entry: entry, controller: controller, badge: "●")
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .onHover { controller.setHovering($0) }
    }
}

// MARK: - Single Bubble View

private struct BubbleItemView: View {
    let entry: BubbleEntry
    let controller: BubbleHubController
    var badge: String? = nil
    var isLauncher: Bool = false
    var isSprouted: Bool = false

    @State private var hovering = false

    private let d = BubbleHubController.diameter

    var body: some View {
        ZStack {
            // ── True Liquid Glass Layered Sphere ───────────────────
            // 1. Deep ambient shadow with glass dispersion
            Circle()
                .fill(.ultraThinMaterial)
                .shadow(
                    color: isLauncher && isSprouted ? Color.accentColor.opacity(0.45) : .black.opacity(hovering ? 0.45 : 0.28),
                    radius: hovering || (isLauncher && isSprouted) ? 12 : 7,
                    x: 0,
                    y: hovering ? 6 : 4
                )

            // 2. Translucent liquid tint / refractive wash
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            isLauncher && isSprouted
                                ? Color.accentColor.opacity(0.28)
                                : Color.white.opacity(hovering ? 0.22 : 0.12),
                            Color.white.opacity(0.04),
                            Color.black.opacity(0.25)
                        ],
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: d * 0.95
                    )
                )

            // 3. Specular liquid glass top-crescent lens reflection
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(hovering ? 0.85 : 0.70),
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: hovering || (isLauncher && isSprouted) ? 1.8 : 1.2
                )

            // 4. Inner liquid meniscus highlight (top crescent)
            Circle()
                .inset(by: 2.5)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(hovering ? 0.45 : 0.30),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 1.0
                )

            // Content Icon
            if isLauncher {
                Image(systemName: isSprouted ? "xmark" : "square.grid.3x3.fill")
                    .font(.system(size: isSprouted ? 17 : 20, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .rotationEffect(.degrees(isSprouted ? 90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSprouted)
            } else if let img = entry.favicon {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: d * 0.55, height: d * 0.55)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: entry.symbolName.isEmpty ? "globe" : entry.symbolName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
            }

            // Indicator Badge for Open App or Suggested
            if let badge = badge, !isLauncher {
                VStack {
                    HStack {
                        Spacer()
                        Text(badge)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(badge == "●" ? Color.green : Color.purple)
                            .padding(2)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    Spacer()
                }
                .frame(width: d, height: d)
            }

            // Hover label
            if hovering && !controller.state.isDragging {
                VStack {
                    Spacer()
                    Text(entry.appName)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.regularMaterial))
                        .padding(.bottom, -10)
                }
            }
        }
        .frame(width: d, height: d)
        .contentShape(Circle())
        .scaleEffect((hovering && !controller.state.isDragging) ? 1.12 : (isLauncher && isSprouted ? 1.05 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.65), value: hovering)
        .onHover { hovering = $0 }
        // Drag gesture and click handling via HubDragRepresentable
        .overlay(HubDragRepresentable(controller: controller, entry: entry))
        .help(tooltipText)
    }

    private var tooltipText: String {
        if isLauncher {
            return isSprouted ? "Click to collapse hub" : "Click to sprout open apps & suggestions"
        }
        switch entry.kind {
        case .launcher:
            return "PhoneBar Hub"
        case .openApp:
            return "\(entry.appName) (Running) — Click to focus · Double-click to toggle"
        case .suggestedOrRecent:
            return "\(entry.appName) (Recent/Suggested) — Click to open"
        }
    }
}

// MARK: - Drag NSView with Click Passthrough

struct HubDragRepresentable: NSViewRepresentable {
    let controller: BubbleHubController
    let entry: BubbleEntry

    func makeNSView(context: Context) -> HubDragNSView {
        HubDragNSView(controller: controller, entry: entry)
    }

    func updateNSView(_ nsView: HubDragNSView, context: Context) {
        nsView.entry = entry
    }
}

final class HubDragNSView: NSView {
    private weak var controller: BubbleHubController?
    var entry: BubbleEntry
    private var mouseStart: NSPoint = .zero
    private var panelStart: NSPoint = .zero
    private var hasMoved = false
    private let dragThreshold: CGFloat = 3.0

    init(controller: BubbleHubController, entry: BubbleEntry) {
        self.controller = controller
        self.entry = entry
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseStart = NSEvent.mouseLocation
        panelStart = window?.frame.origin ?? .zero
        hasMoved = false
    }

    override func mouseDragged(with event: NSEvent) {
        let cur = NSEvent.mouseLocation
        let dx = cur.x - mouseStart.x
        let dy = cur.y - mouseStart.y
        if !hasMoved && (abs(dx) > dragThreshold || abs(dy) > dragThreshold) {
            hasMoved = true
            Task { @MainActor [weak controller] in
                controller?.state.isDragging = true
            }
        }

        if hasMoved, let w = window {
            w.setFrameOrigin(NSPoint(x: panelStart.x + dx, y: panelStart.y + dy))
        }
    }

    override func mouseUp(with event: NSEvent) {
        if hasMoved {
            Task { @MainActor [weak controller] in
                guard let controller = controller else { return }
                controller.state.isDragging = false
                controller.didEndDrag()
            }
        } else {
            // Quick click or double click
            let clickCount = event.clickCount
            Task { @MainActor [weak controller, entry] in
                guard let controller = controller else { return }
                if clickCount >= 2 {
                    controller.doubleTap(entry: entry)
                } else {
                    controller.singleTap(entry: entry)
                }
            }
        }
    }
}
