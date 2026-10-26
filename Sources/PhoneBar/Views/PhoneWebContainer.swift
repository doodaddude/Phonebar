import AppKit
import SwiftUI
import WebKit

/// NSView that enables native dragging of the parent window when clicked/dragged.
final class WindowDragNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        window.performDrag(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

struct WindowDragRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragNSView {
        WindowDragNSView()
    }
    func updateNSView(_ nsView: WindowDragNSView, context: Context) {}
}

/// NSView that enables smooth diagonal window resizing by dragging the bottom-right corner.
final class WindowResizeNSView: NSView {
    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowFrame: NSRect = .zero

    override func resetCursorRects() {
        super.resetCursorRects()
        if let cursor = NSCursor.perform(Selector(("_windowResizeNorthWestSouthEastCursor")))?.takeUnretainedValue() as? NSCursor {
            addCursorRect(bounds, cursor: cursor)
        } else {
            addCursorRect(bounds, cursor: .crosshair)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowFrame = window.frame
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }
        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - initialMouseLocation.x
        let deltaY = currentMouse.y - initialMouseLocation.y

        var newWidth = max(280, initialWindowFrame.width + deltaX)
        var newHeight = max(380, initialWindowFrame.height - deltaY)

        let screenFrame = window.screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        newWidth = min(newWidth, screenFrame.width - 20)
        newHeight = min(newHeight, screenFrame.height - 30)

        // Keep pinned to the top under menu bar
        let newY = initialWindowFrame.maxY - newHeight
        window.setFrame(NSRect(x: initialWindowFrame.minX, y: newY, width: newWidth, height: newHeight), display: true)
    }
}

struct WindowResizeRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowResizeNSView {
        WindowResizeNSView()
    }
    func updateNSView(_ nsView: WindowResizeNSView, context: Context) {}
}

struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

/// Phone-like web container with traffic lights on grabber bar, user persona switcher, and diagonal scaling.
struct PhoneWebContainer: View {
    @ObservedObject var model: WebViewModel
    var onDeviceChange: ((DevicePreset) -> Void)?
    var onNewInstance: (() -> Void)?
    var onOpenInBrowser: (() -> Void)?
    var onCloseWindow: (() -> Void)?
    var onMiniaturizeWindow: (() -> Void)?
    var onZoomWindow: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            SlimTopHeaderBar(
                model: model,
                onDeviceChange: onDeviceChange,
                onNewInstance: onNewInstance,
                onOpenInBrowser: onOpenInBrowser,
                onCloseWindow: onCloseWindow,
                onMiniaturizeWindow: onMiniaturizeWindow,
                onZoomWindow: onZoomWindow
            )
            WebViewRepresentable(webView: model.webView)
            ControlBar(
                model: model,
                onOpenInBrowser: onOpenInBrowser
            )
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.white.opacity(0.1),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 8)
    }
}

/// Very slim top header bar (24pt) with traffic lights directly on the bar, draggable grabber, user switcher, and viewport menus.
private struct SlimTopHeaderBar: View {
    @ObservedObject var model: WebViewModel
    @StateObject private var proxy = ProxyService.shared
    var onDeviceChange: ((DevicePreset) -> Void)?
    var onNewInstance: (() -> Void)?
    var onOpenInBrowser: (() -> Void)?
    var onCloseWindow: (() -> Void)?
    var onMiniaturizeWindow: (() -> Void)?
    var onZoomWindow: (() -> Void)?
    @State private var grabberHovering = false
    @State private var themePreference: String = UserDefaults.standard.string(forKey: "PhoneBar.barThemeColor") ?? "favicon"

    private var barThemeColor: Color {
        switch themePreference {
        case "accent":
            return Color.accentColor
        case "glass":
            return Color.secondary.opacity(0.18)
        case "indigo":
            return Color.indigo
        case "obsidian":
            return Color.black.opacity(0.7)
        case "emerald":
            return Color.green
        case "crimson":
            return Color.red
        default:
            return FaviconService.shared.dominantColor(for: model.config.host)
        }
    }

    private var dominantColor: Color {
        barThemeColor
    }

    var body: some View {
        HStack(spacing: 5) {
            // Traffic Light Buttons directly on the grabber bar!
            TrafficLightButtons(
                onClose: onCloseWindow,
                onMiniaturize: onMiniaturizeWindow,
                onZoom: onZoomWindow
            )

            // Center Ultra-Slim Draggable Grabber Handle with clear visual shading
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(grabberHovering ? dominantColor : Color.primary.opacity(0.45))
                    Text("Drag")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(grabberHovering ? dominantColor : Color.primary.opacity(0.45))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 1.5)
                .background(
                    Capsule()
                        .fill(grabberHovering ? dominantColor.opacity(0.24) : Color.primary.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(grabberHovering ? dominantColor.opacity(0.5) : Color.white.opacity(0.18), lineWidth: 0.8)
                )
                Spacer()
            }
            .frame(maxHeight: .infinity)
            .background(WindowDragRepresentable())
            .onHover { grabberHovering = $0 }
            .help("Drag to move window anywhere on screen")

            // User / Persona Button (Switch between Anonymous and Saved Accounts)
            AccountUserButton(model: model)

            // Unified Matched Region (IP + GPS + TimeZone)
            Menu {
                if !proxy.customProfiles.isEmpty {
                    Section("My Custom VPNs") {
                        ForEach(proxy.customProfiles) { prof in
                            Button {
                                proxy.selectProfile(prof)
                                model.setLocationSpoofing(
                                    enabled: true,
                                    location: SpoofedLocation(
                                        name: "\(prof.city), \(prof.countryCode)",
                                        latitude: prof.latitude,
                                        longitude: prof.longitude,
                                        countryCode: prof.countryCode,
                                        flagEmoji: prof.flagEmoji,
                                        timezone: prof.timezone,
                                        timezoneOffsetMinutes: prof.timezoneOffsetMinutes,
                                        locale: prof.locale,
                                        isCustomVPN: prof.isCustom
                                    )
                                )
                            } label: {
                                HStack {
                                    Text("\(prof.flagEmoji) \(prof.name) (\(prof.proxyType == .socks5 ? "SOCKS5" : "HTTP"))")
                                    if proxy.selectedProfile.id == prof.id && (proxy.isProxyEnabled || model.isSpoofingLocation) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Preset Regions") {
                    ForEach(SpoofProfile.profiles) { prof in
                        Button {
                            proxy.selectProfile(prof)
                            model.setLocationSpoofing(
                                enabled: true,
                                location: SpoofedLocation(
                                    name: "\(prof.city), \(prof.countryCode)",
                                    latitude: prof.latitude,
                                    longitude: prof.longitude,
                                    countryCode: prof.countryCode,
                                    flagEmoji: prof.flagEmoji,
                                    timezone: prof.timezone,
                                    timezoneOffsetMinutes: prof.timezoneOffsetMinutes,
                                    locale: prof.locale,
                                    isCustomVPN: false
                                )
                            )
                        } label: {
                            HStack {
                                Text("\(prof.flagEmoji) \(prof.name)")
                                if proxy.selectedProfile.id == prof.id && (proxy.isProxyEnabled || model.isSpoofingLocation) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Divider()

                Section("Controls") {
                    Button {
                        proxy.rotateToNextBackupProxy()
                        model.webView.reload()
                    } label: {
                        Label("Rotate to Next IP in \(proxy.selectedProfile.name)", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!proxy.isProxyEnabled)

                    Button {
                        model.setLocationSpoofing(enabled: !model.isSpoofingLocation, location: model.currentLocation)
                    } label: {
                        HStack {
                            Text(model.isSpoofingLocation ? "Disable GPS Spoofing" : "Enable GPS Spoofing")
                            Image(systemName: model.isSpoofingLocation ? "checkmark.circle" : "circle")
                        }
                    }

                    Button {
                        proxy.isProxyEnabled.toggle()
                        model.webView.reload()
                    } label: {
                        HStack {
                            Text(proxy.isProxyEnabled ? "Disable IP Proxy" : "Enable IP Proxy")
                            Image(systemName: proxy.isProxyEnabled ? "checkmark.circle" : "circle")
                        }
                    }

                    Button("Reset to Real Location (Direct)") {
                        proxy.isProxyEnabled = false
                        model.setLocationSpoofing(enabled: false, location: model.currentLocation)
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    if proxy.isProxyEnabled || model.isSpoofingLocation {
                        Text(proxy.selectedProfile.flagEmoji)
                            .font(.system(size: 8.5))
                        Text(proxy.selectedProfile.countryCode)
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(proxy.isProxyEnabled ? Color.green : Color.blue)
                    } else {
                        Image(systemName: "location.slash")
                            .font(.system(size: 7.5))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 5.5, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill((proxy.isProxyEnabled && model.isSpoofingLocation) ? Color.green.opacity(0.12) : Color.primary.opacity(0.06))
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Synchronized Region (IP + GPS): \(proxy.selectedProfile.name)")

            // Mini Device Switcher Button
            Menu {
                ForEach(DeviceType.allCases) { type in
                    Section {
                        ForEach(DevicePreset.devices(for: type)) { preset in
                            Button {
                                onDeviceChange?(preset)
                            } label: {
                                HStack {
                                    Label(preset.rawValue, systemImage: preset.iconName)
                                    Spacer()
                                    Text(preset.resolutionString)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if model.config.devicePreset == preset {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .help("\(preset.rawValue) — Resolution: \(preset.resolutionString)")
                        }
                    } header: {
                        Label(type.rawValue, systemImage: type.iconName)
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: model.config.devicePreset.iconName)
                        .font(.system(size: 8, weight: .semibold))
                    Text(shortDeviceName(model.config.devicePreset))
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 5.5, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4.5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Switch device viewport")

            // Screen & Browsing Behaviours Menu
            Menu {
                Section("Page Zoom (\(Int(model.pageZoom * 100))%)") {
                    ForEach([0.75, 0.85, 1.0, 1.15, 1.25], id: \.self) { z in
                        Button("\(Int(z * 100))%") {
                            model.pageZoom = z
                        }
                    }
                }

                Section("Window Opacity (\(Int(model.windowOpacity * 100))%)") {
                    ForEach([1.0, 0.90, 0.75, 0.60, 0.45], id: \.self) { op in
                        Button(model.windowOpacity == op ? "✓ \(Int(op * 100))%" : "\(Int(op * 100))%") {
                            model.windowOpacity = op
                        }
                    }
                }

                Section("Ghost / Click-Through") {
                    Button {
                        model.isGhostMode.toggle()
                    } label: {
                        HStack {
                            Text("Ghost Click-Through")
                            Image(systemName: model.isGhostMode ? "checkmark.circle" : "circle")
                        }
                    }
                }

                Section("Browsing Controls") {
                    Button {
                        AdBlockService.shared.isEnabled.toggle()
                    } label: {
                        HStack {
                            Text("Ad & Tracker Blocker")
                            Image(systemName: AdBlockService.shared.isEnabled ? "checkmark.circle" : "circle")
                        }
                    }

                    Button {
                        model.isForceDarkMode.toggle()
                    } label: {
                        HStack {
                            Text("Force Dark Mode")
                            Image(systemName: model.isForceDarkMode ? "checkmark.circle" : "circle")
                        }
                    }

                    Button {
                        model.isAudioMuted.toggle()
                    } label: {
                        HStack {
                            Text("Mute Audio")
                            Image(systemName: model.isAudioMuted ? "checkmark.circle" : "circle")
                        }
                    }

                    Button {
                        model.isDesktopMode.toggle()
                    } label: {
                        HStack {
                            Text(model.isDesktopMode ? "Switch to Mobile View" : "Request Desktop Site")
                            Image(systemName: model.isDesktopMode ? "checkmark.circle" : "circle")
                        }
                    }
                }

                Divider()

                if let onNewInstance = onNewInstance {
                    Button {
                        onNewInstance()
                    } label: {
                        Label("Open Duplicate Instance", systemImage: "plus.rectangle.on.rectangle")
                    }
                }

                Button {
                    model.clearHostCacheAndReload()
                } label: {
                    Label("Clear Site Cache & Reload", systemImage: "trash")
                }

                if let onOpenInBrowser = onOpenInBrowser {
                    Button {
                        onOpenInBrowser()
                    } label: {
                        Label("Open in \(model.config.companionBrowser ?? "Companion Browser")", systemImage: "arrow.up.right.square")
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Screen Behaviours: Zoom, Auto-refresh, Dark mode, Mute, Clear cache")

            // Quick AdBlock Toggle with clear icon and label
            Button {
                AdBlockService.shared.isEnabled.toggle()
            } label: {
                HStack(spacing: 2.5) {
                    Image(systemName: AdBlockService.shared.isEnabled ? "shield.checkered" : "shield.slash")
                        .font(.system(size: 8, weight: .bold))
                    Text(AdBlockService.shared.isEnabled ? "AdBlock" : "Ads On")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(AdBlockService.shared.isEnabled ? Color.blue : Color.secondary.opacity(0.8))
                .padding(.horizontal, 4.5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AdBlockService.shared.isEnabled ? Color.blue.opacity(0.14) : Color.primary.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
            .help(AdBlockService.shared.isEnabled ? "Ad & Tracker Blocker: Active (Click to toggle)" : "Ad & Tracker Blocker: Disabled (Click to block ads)")
        }
        .padding(.horizontal, 6)
        .frame(height: 24)
        .background(
            ZStack {
                // Full-bar drag layer — sits below all interactive controls.
                // isMovableByWindowBackground = true on the window means AppKit forwards
                // unhandled clicks here, but SwiftUI Spacers may not propagate. This NSView
                // layer guarantees every pixel that isn't a button acts as a drag handle.
                WindowDragRepresentable()
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(dominantColor.opacity(0.15))
            }
        )
        .overlay(alignment: .bottom) {
            Divider()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appearanceSettingsChanged)) { _ in
            themePreference = UserDefaults.standard.string(forKey: "PhoneBar.barThemeColor") ?? "favicon"
        }
    }

    private func shortDeviceName(_ preset: DevicePreset) -> String {
        // Grouped short labels
        switch preset {
        case .palmCompact:        return "Palm"
        case .iPhoneMini:         return "Mini"
        case .iPhoneSE:           return "SE"
        case .iPhone16Pro:        return "16 Pro"
        case .iPhone16ProMax:     return "Max"
        case .pixel9:             return "Pixel 9"
        case .galaxyS24:          return "S24"
        case .nokiaLumia:         return "Lumia"
        case .blackBerryPassport: return "BB Pass"
        case .amazonFireHD:       return "Fire HD"
        case .kindlePaperwhite:   return "Kindle"
        case .samsungGalaxyFold:  return "Z Fold"
        case .huaweiP50Pro:       return "P50 Pro"
        case .xiaomiMi13:         return "Mi 13"
        case .oppoFindX6:         return "Find X6"
        case .vivoX100:           return "X100"
        case .tecnoSpark:         return "Tecno"
        case .infinixNote:        return "Infinix"
        case .nokiaG60:           return "G60"
        case .motorolaG84:        return "G84"
        case .sonyXperia1:        return "Xperia"
        case .googleTV:           return "Google TV"
        case .samsungSmartTV:     return "Tizen TV"
        case .lgWebOS:            return "webOS TV"
        case .playStation5:       return "PS5"
        case .nintendoSwitch:     return "Switch"
        case .wiiU:               return "Wii U"
        case .xboxSeriesX:        return "Xbox"
        case .oculus2:            return "Quest 2"
        case .appleWatch:         return "Watch"
        case .baiduBox:           return "Baidu"
        case .chromebook:         return "Chrome OS"
        case .iPadMini:           return "iPad Mini"
        case .iPadPro:            return "iPad Pro"
        case .desktopMac:         return "Safari"
        case .desktopChrome:      return "Chrome"
        }
    }
}

/// Traffic Light Buttons directly on the grabber bar.
struct TrafficLightButtons: View {
    var onClose: (() -> Void)?
    var onMiniaturize: (() -> Void)?
    var onZoom: (() -> Void)?
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 5.5) {
            // Close (Red)
            Button {
                onClose?()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.36, blue: 0.32))
                        .frame(width: 10.5, height: 10.5)
                    if hovering {
                        Image(systemName: "xmark")
                            .font(.system(size: 5.5, weight: .black))
                            .foregroundStyle(Color.black.opacity(0.65))
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Close window (⌘W)")

            // Miniaturize / Genie to Menu Bar (Yellow)
            Button {
                onMiniaturize?()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.74, blue: 0.18))
                        .frame(width: 10.5, height: 10.5)
                    if hovering {
                        Image(systemName: "minus")
                            .font(.system(size: 6, weight: .black))
                            .foregroundStyle(Color.black.opacity(0.65))
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Minimize to menu bar with genie scale effect")

            // Zoom / Viewport Expand (Green)
            Button {
                onZoom?()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.16, green: 0.80, blue: 0.25))
                        .frame(width: 10.5, height: 10.5)
                    if hovering {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 5, weight: .black))
                            .foregroundStyle(Color.black.opacity(0.65))
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Toggle zoom / expand viewport")
        }
        .padding(.leading, 3)
        .padding(.trailing, 2)
        .onHover { hovering = $0 }
    }
}

/// Account / Persona switcher button in the top header.
struct AccountUserButton: View {
    @ObservedObject var model: WebViewModel

    var body: some View {
        Menu {
            Section("Current Persona: \(model.currentAccountProfile.name)") {
                Button {
                    model.switchAccount(to: .anonymous)
                } label: {
                    HStack {
                        Text("🕶️ Anonymous (Incognito)")
                        if model.currentAccountProfile.isAnonymous {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    model.switchAccount(to: .defaultProfile)
                } label: {
                    HStack {
                        Text("👤 Computer Default")
                        if !model.currentAccountProfile.isAnonymous && model.currentAccountProfile.id == "default" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Section("Saved Personas") {
                ForEach(AccountProfile.defaultProfiles.filter { $0.id != "default" && !$0.isAnonymous }) { prof in
                    Button {
                        model.switchAccount(to: prof)
                    } label: {
                        HStack {
                            Text("\(prof.avatarEmoji) \(prof.name)")
                            if model.currentAccountProfile.id == prof.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Section("Session Details") {
                if model.currentAccountProfile.isAnonymous {
                    Label("Ephemeral: zero cookies or tokens stored on disk", systemImage: "shield.slash")
                } else {
                    Label("Persistent: computer logins saved", systemImage: "lock.shield")
                }
            }
        } label: {
            HStack(spacing: 2) {
                if model.currentAccountProfile.isAnonymous {
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.purple)
                    Text("Anon")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(Color.purple)
                } else {
                    Text(model.currentAccountProfile.avatarEmoji)
                        .font(.system(size: 8))
                    Text(model.currentAccountProfile.id == "default" ? "Default" : model.currentAccountProfile.name)
                        .font(.system(size: 8.5, weight: .medium))
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 5.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(model.currentAccountProfile.isAnonymous ? Color.purple.opacity(0.12) : Color.primary.opacity(0.06))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Switch identity/account: \(model.currentAccountProfile.name)")
    }
}

/// Control bar with navigation controls, center app name draggable grabber, and diagonal corner resize grabber.
private struct ControlBar: View {
    @ObservedObject var model: WebViewModel
    var onOpenInBrowser: (() -> Void)?
    @State private var bottomGrabberHovering = false
    @State private var themePreference: String = UserDefaults.standard.string(forKey: "PhoneBar.barThemeColor") ?? "favicon"

    private var barThemeColor: Color {
        switch themePreference {
        case "accent":
            return Color.accentColor
        case "glass":
            return Color.secondary.opacity(0.18)
        case "indigo":
            return Color.indigo
        case "obsidian":
            return Color.black.opacity(0.7)
        case "emerald":
            return Color.green
        case "crimson":
            return Color.red
        default:
            return FaviconService.shared.dominantColor(for: model.config.host)
        }
    }

    private var dominantColor: Color {
        barThemeColor
    }

    var body: some View {
        HStack(spacing: 2) {
            barButton("chevron.left", help: "Back (⌘[)", enabled: model.canGoBack) {
                model.webView.goBack()
            }
            barButton("chevron.right", help: "Forward (⌘])", enabled: model.canGoForward) {
                model.webView.goForward()
            }
            barButton(model.isLoading ? "xmark" : "arrow.clockwise",
                      help: model.isLoading ? "Stop" : "Reload (⌘R)", enabled: true) {
                model.reloadOrStop()
            }

            Spacer(minLength: 4)

            // Center App Name & Bottom Draggable Grabber Area
            HStack(spacing: 3) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(bottomGrabberHovering ? dominantColor : Color.primary.opacity(0.45))

                Text(model.config.name)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(bottomGrabberHovering ? dominantColor : Color.primary.opacity(0.85))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(bottomGrabberHovering ? dominantColor.opacity(0.25) : Color.primary.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .strokeBorder(bottomGrabberHovering ? dominantColor.opacity(0.55) : Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .background(WindowDragRepresentable())
            .onHover { bottomGrabberHovering = $0 }
            .help("Drag to move window anywhere on screen")

            Spacer(minLength: 4)

            if let openInBrowser = onOpenInBrowser {
                barButton("arrow.up.right.square",
                          help: "Open in \(model.config.companionBrowser ?? "Companion Browser")",
                          enabled: true) {
                    openInBrowser()
                }
            }

            // Small Moon Icon to the left of the house icon (Toggles site force dark mode)
            barButton(model.isForceDarkMode ? "moon.fill" : "moon",
                      help: model.isForceDarkMode ? "Disable Force Dark Mode" : "Enable Force Dark Mode",
                      enabled: true,
                      activeColor: Color.indigo) {
                model.isForceDarkMode.toggle()
            }

            barButton("house", help: "Home", enabled: true) {
                model.goHome()
            }
            barButton(model.isPinned ? "pin.fill" : "pin",
                      help: model.isPinned ? "Floating: on" : "Floating: off", enabled: true) {
                model.isPinned.toggle()
            }

            // Diagonal Corner Resize Grabber
            CornerResizeGrabber()
        }
        .padding(.horizontal, 6)
        .frame(height: 32)
        .background(
            ZStack {
                // Full-bar drag layer — ensures the bottom bar is grabbable everywhere,
                // not only over the centre capsule.
                WindowDragRepresentable()
                Rectangle().fill(.bar)
                Rectangle().fill(dominantColor.opacity(0.15))
            }
        )
        .overlay(alignment: .top) {
            ZStack(alignment: .leading) {
                Divider()
                if model.isLoading {
                    GeometryReader { geo in
                        Rectangle().fill(Color.accentColor)
                            .frame(width: geo.size.width * model.progress, height: 2)
                    }
                    .frame(height: 2)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appearanceSettingsChanged)) { _ in
            themePreference = UserDefaults.standard.string(forKey: "PhoneBar.barThemeColor") ?? "favicon"
        }
    }

    private func barButton(_ symbol: String, help: String, enabled: Bool,
                           activeColor: Color? = nil,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(activeColor ?? .primary)
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .help(help)
    }
}

/// Corner resize grabber with diagonal grip ridges and native diagonal resizing.
struct CornerResizeGrabber: View {
    @State private var hovering = false

    var body: some View {
        ZStack {
            WindowResizeRepresentable()
                .frame(width: 18, height: 18)

            // 3 Diagonal grip lines
            Path { path in
                path.move(to: CGPoint(x: 13, y: 5))
                path.addLine(to: CGPoint(x: 5, y: 13))

                path.move(to: CGPoint(x: 13, y: 8.5))
                path.addLine(to: CGPoint(x: 8.5, y: 13))

                path.move(to: CGPoint(x: 13, y: 12))
                path.addLine(to: CGPoint(x: 12, y: 13))
            }
            .stroke(Color.primary.opacity(hovering ? 0.6 : 0.22), lineWidth: 1.3)
        }
        .frame(width: 18, height: 20)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .help("Drag corner to resize window diagonally")
    }
}
