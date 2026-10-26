import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var windows: WindowManager
    @StateObject private var proxy = ProxyService.shared

    @State private var selectedCategory: ExtensionCategory? = nil
    @State private var searchText = ""
    @State private var isAdding = false
    @State private var showPreferences = false
    @State private var showHistory = false
    @State private var showAllSuggested = false
    @State private var newName = ""
    @State private var newURL = ""
    @State private var newCategory: ExtensionCategory = .aiAndDev
    @State private var newDevice: DevicePreset = .iPhoneMini
    @State private var newBrowser = "Google Chrome"
    @State private var showError = false
    @State private var cacheClearedStatus = false

    // 4 columns of narrow cards
    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    private var filteredApps: [WebAppConfig] {
        store.apps.filter { app in
            let matchesCategory = selectedCategory == nil || app.category == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.urlString.localizedCaseInsensitiveContains(searchText) ||
                app.category.rawValue.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    // MARK: – Page enum for clean transitions
    private enum Page { case apps, preferences, history }

    private var currentPage: Page {
        if showPreferences { return .preferences }
        if showHistory { return .history }
        return .apps
    }

    @AppStorage("PhoneBar.menuHeight") private var menuHeight: Double = 560
    @State private var isDraggingResize = false
    @State private var initialDragHeight: Double = 560

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            // Resizable-height container with saved user preference
            ZStack(alignment: .top) {
                // ── Apps page ──────────────────────────────────────────────
                appsPageContent
                    .opacity(currentPage == .apps ? 1 : 0)
                    .allowsHitTesting(currentPage == .apps)

                // ── Preferences page ───────────────────────────────────────
                PreferencesView(onClose: {
                    withAnimation(.easeInOut(duration: 0.22)) { showPreferences = false }
                })
                .opacity(currentPage == .preferences ? 1 : 0)
                .allowsHitTesting(currentPage == .preferences)

                // ── History page ───────────────────────────────────────────
                HistoryTimelineView(onClose: {
                    withAnimation(.easeInOut(duration: 0.22)) { showHistory = false }
                })
                .opacity(currentPage == .history ? 1 : 0)
                .allowsHitTesting(currentPage == .history)
            }
            .animation(.easeInOut(duration: 0.22), value: currentPage)
            .frame(height: max(380, min(860, CGFloat(menuHeight))), alignment: .top)

            if currentPage == .apps {
                Divider()
                footer
            }

            // Resizable grab bar at the bottom edge
            resizeHandleBar
        }
        .padding(12)
        .frame(width: 410, alignment: .top)
        .background(.ultraThinMaterial)
    }

    // MARK: – Apps page (scroll + floating FAB + overlay add-form)
    private var appsPageContent: some View {
        VStack(spacing: 7) {
            // Search Field
            searchBar

            // Category Options: Small Square Tiles
            categorySquareTilesBar

            // Scrollable App Sections + Floating Add Button + Overlay Add Form
            ZStack(alignment: .bottomTrailing) {

                // ── Scroll view – never moves ──────────────────────────────
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if selectedCategory == nil && searchText.isEmpty {
                            // 1. My Added Apps
                            if !store.myAddedApps.isEmpty {
                                sectionHeader("star.fill", title: "My Apps", count: store.myAddedApps.count, color: .orange)
                                LazyVGrid(columns: columns, spacing: 6) {
                                    ForEach(store.myAddedApps) { app in appTileView(app: app) }
                                }
                            }

                            // 2. Recently Opened
                            if !store.recentlyOpenedApps.isEmpty {
                                sectionHeader("clock.arrow.circlepath", title: "Recently Opened", count: store.recentlyOpenedApps.count, color: .blue)
                                LazyVGrid(columns: columns, spacing: 6) {
                                    ForEach(store.recentlyOpenedApps) { app in appTileView(app: app) }
                                }
                            }

                            // 3. Suggested Library (lazy, loads more on scroll-reveal)
                            let suggestions = store.suggestedApps
                            if !suggestions.isEmpty {
                                sectionHeader("sparkles.rectangle.stack", title: "Suggested Library", count: suggestions.count, color: .purple)
                                let visible = showAllSuggested ? suggestions : Array(suggestions.prefix(12))
                                LazyVGrid(columns: columns, spacing: 6) {
                                    ForEach(visible) { app in appTileView(app: app) }
                                }
                                if !showAllSuggested && suggestions.count > 12 {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) { showAllSuggested = true }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "chevron.down").font(.caption2)
                                            Text("Show \(suggestions.count - 12) More Suggestions").font(.caption)
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            if filteredApps.isEmpty {
                                VStack(spacing: 6) {
                                    Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                                    Text("No apps match your filter.").font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 32)
                            } else {
                                LazyVGrid(columns: columns, spacing: 6) {
                                    ForEach(filteredApps) { app in appTileView(app: app) }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.bottom, 56) // room for FAB
                }

                // ── Floating Add button (FAB) ──────────────────────────────
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { isAdding.toggle() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 40, height: 40)
                            .shadow(color: Color.accentColor.opacity(0.45), radius: 6, x: 0, y: 3)
                            .overlay(
                                Circle().strokeBorder(
                                    LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.1)],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 1)
                            )
                        Image(systemName: isAdding ? "xmark" : "plus")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(isAdding ? 90 : 0))
                    }
                }
                .buttonStyle(.plain)
                .help(isAdding ? "Close Add Form" : "Add App")
                .padding(.trailing, 4).padding(.bottom, 4)
                .zIndex(1)

                // ── Floating slide-up Add-App sheet (overlay, zero layout shift) ──
                if isAdding {
                    addFormDrawer
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(2)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            // Left Group: Location & Identity Profile Pill
            Menu {
                if !proxy.customProfiles.isEmpty {
                    Section("My Custom VPNs") {
                        ForEach(proxy.customProfiles) { prof in
                            Button {
                                proxy.selectProfile(prof, store: store)
                            } label: {
                                HStack {
                                    Text("\(prof.flagEmoji) \(prof.name) (\(prof.proxyType == .socks5 ? "SOCKS5" : "HTTP"))")
                                    if (proxy.isProxyEnabled || store.isLocationSpoofingEnabled) && proxy.selectedProfile.id == prof.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Preset Regions (IP + GPS + TimeZone)") {
                    ForEach(SpoofProfile.profiles) { prof in
                        Button {
                            proxy.selectProfile(prof, store: store)
                        } label: {
                            HStack {
                                Text("\(prof.flagEmoji) \(prof.name)")
                                if (proxy.isProxyEnabled || store.isLocationSpoofingEnabled) && proxy.selectedProfile.id == prof.id {
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
                    } label: {
                        Label("Rotate to Next IP in \(proxy.selectedProfile.name)", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!proxy.isProxyEnabled)

                    Button {
                        store.isLocationSpoofingEnabled.toggle()
                    } label: {
                        HStack {
                            Text(store.isLocationSpoofingEnabled ? "Disable GPS Spoofing" : "Enable GPS Spoofing")
                            Image(systemName: store.isLocationSpoofingEnabled ? "checkmark.circle" : "circle")
                        }
                    }

                    Button {
                        proxy.isProxyEnabled.toggle()
                    } label: {
                        HStack {
                            Text(proxy.isProxyEnabled ? "Disable IP Proxy" : "Enable IP Proxy")
                            Image(systemName: proxy.isProxyEnabled ? "checkmark.circle" : "circle")
                        }
                    }

                    Button("Reset to Real Location (Bypass All)") {
                        proxy.isProxyEnabled = false
                        store.isLocationSpoofingEnabled = false
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if proxy.isProxyEnabled || store.isLocationSpoofingEnabled {
                        Text(proxy.selectedProfile.flagEmoji)
                            .font(.system(size: 11.5))
                        Text(proxy.selectedProfile.city)
                            .font(.system(size: 10.5, weight: .bold))
                            .lineLimit(1)
                    } else {
                        Image(systemName: "location.slash")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                        Text("Real Identity")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill((proxy.isProxyEnabled && store.isLocationSpoofingEnabled) ? Color.green.opacity(0.16) : Color.primary.opacity(0.06))
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Synchronized Region Profile: \(proxy.selectedProfile.name)")

            // GPS Pill
            Button {
                store.isLocationSpoofingEnabled.toggle()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9))
                    Text("GPS")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3.5)
                .background(Capsule().fill(store.isLocationSpoofingEnabled ? Color.blue.opacity(0.18) : Color.primary.opacity(0.06)))
                .foregroundStyle(store.isLocationSpoofingEnabled ? Color.blue : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(store.isLocationSpoofingEnabled ? "GPS Spoofing Active (Click to toggle)" : "GPS Spoofing Off")

            // IP Pill
            Button {
                proxy.isProxyEnabled.toggle()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "network")
                        .font(.system(size: 9.5))
                    Text("IP")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3.5)
                .background(Capsule().fill(proxy.isProxyEnabled ? Color.green.opacity(0.18) : Color.primary.opacity(0.06)))
                .foregroundStyle(proxy.isProxyEnabled ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(proxy.isProxyEnabled ? "IP Proxy Active (\(proxy.currentProxy.host)). Click to toggle." : "IP Proxy Off")

            // Rotate Proxy Pill
            if proxy.isProxyEnabled {
                Button {
                    proxy.rotateToNextBackupProxy()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Rotate to next proxy IP in \(proxy.selectedProfile.name)")
            }

            // Dark Mode Pill
            Button {
                store.globalForceDarkMode.toggle()
            } label: {
                Image(systemName: store.globalForceDarkMode ? "moon.fill" : "moon")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(store.globalForceDarkMode ? Color.indigo : Color.secondary)
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(store.globalForceDarkMode ? Color.indigo.opacity(0.24) : Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help(store.globalForceDarkMode ? "Force Dark Mode Enabled for All Apps (Click to toggle)" : "Force Dark Mode Disabled (Click to enable)")

            // Running Instances Count Pill
            if !showPreferences && !showHistory && !windows.instances.isEmpty {
                HStack(spacing: 3.5) {
                    Circle().fill(Color.green).frame(width: 5.5, height: 5.5)
                    Text("\(windows.instances.count)")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 5.5)
                .padding(.vertical, 3.5)
                .background(Capsule().fill(Color.green.opacity(0.14)))
            }

            Spacer()

            // Right Group: Ellipsis Menu, History, and Preferences Pills
            if !showPreferences && !showHistory {
                Menu {
                    Button("Reset All 300 Defaults") { store.resetToDefaults() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            // History Pill Button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showHistory.toggle()
                    if showHistory { showPreferences = false }
                }
            } label: {
                Image(systemName: showHistory ? "xmark" : "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(showHistory ? Color.orange : Color.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(showHistory ? Color.orange.opacity(0.18) : Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help(showHistory ? "Back to Apps" : "History & Timeline")

            // Preferences Pill Button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showPreferences.toggle()
                    if showPreferences { showHistory = false }
                }
            } label: {
                Image(systemName: showPreferences ? "xmark" : "gearshape")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(showPreferences ? Color.accentColor : Color.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(showPreferences ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help(showPreferences ? "Back to Apps" : "Preferences")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption2)
            TextField("Search web apps...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.caption)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4.5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    /// Category options rendered as small square tiles with vibrant Apple HIG category colors
    private var categorySquareTilesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5.5) {
                // "All" Square Tile
                Button {
                    selectedCategory = nil
                } label: {
                    VStack(spacing: 2.5) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 13))
                        Text("All")
                            .font(.system(size: 8, weight: selectedCategory == nil ? .bold : .medium))
                            .lineLimit(1)
                    }
                    .frame(width: 42, height: 42)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                                .fill(selectedCategory == nil ? Color.accentColor : Color.clear)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                            .strokeBorder(selectedCategory == nil ? Color.white.opacity(0.45) : Color.primary.opacity(0.09), lineWidth: 1)
                    )
                    .foregroundStyle(selectedCategory == nil ? Color.white : Color.primary)
                    .shadow(color: selectedCategory == nil ? Color.accentColor.opacity(0.4) : .clear, radius: 4, x: 0, y: 2)
                    .scaleEffect(selectedCategory == nil ? 1.05 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: selectedCategory)
                }
                .buttonStyle(.plain)

                // Category Square Tiles – each with its own vibrant brand color
                ForEach(ExtensionCategory.allCases, id: \.self) { cat in
                    categoryTile(cat)
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func categoryTile(_ cat: ExtensionCategory) -> some View {
        let isSelected: Bool = selectedCategory == cat
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedCategory = isSelected ? nil : cat
            }
        } label: {
            VStack(spacing: 2.5) {
                Image(systemName: cat.iconName)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(cat.color))
                Text(cat.shortName)
                    .font(.system(size: 7.5, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(Color.primary))
            }
            .frame(width: 42, height: 42)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                        .fill(cat.color.opacity(isSelected ? 1.0 : 0.10))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isSelected
                                ? [Color.white.opacity(0.55), cat.color.opacity(0.3)]
                                : [Color.primary.opacity(0.09), Color.primary.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: 1)
            )
            .shadow(color: cat.color.opacity(isSelected ? 0.45 : 0), radius: 5, x: 0, y: 2)
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .help(cat.rawValue)
    }

    private func sectionHeader(_ icon: String, title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private func appTileView(app: WebAppConfig) -> some View {
        AppTile(
            app: app,
            openCount: windows.openCount(for: app.id),
            onOpen: {
                windows.open(app, store: store)
            },
            onNewInstance: {
                windows.open(app, store: store, forceNewInstance: true)
            },
            onDeviceChange: { preset in
                store.updateDevice(id: app.id, device: preset)
            }
        )
        .contextMenu {
            Button("Open") { windows.open(app, store: store) }
            Button("Open Another Instance") { windows.open(app, store: store, forceNewInstance: true) }
            Button("Open in \(app.companionBrowser ?? "Companion Browser")") {
                store.openInBrowser(app: app)
            }

            Divider()

            Button(app.isCustom ? "Unpin from My Apps" : "Pin to My Apps") {
                store.toggleCustom(id: app.id)
            }

            Menu("Device Viewport") {
                ForEach(DeviceType.allCases) { type in
                    Section {
                        ForEach(DevicePreset.devices(for: type)) { device in
                            Button {
                                store.updateDevice(id: app.id, device: device)
                            } label: {
                                HStack {
                                    Label(device.rawValue, systemImage: device.iconName)
                                    Spacer()
                                    Text(device.resolutionString)
                                    if app.devicePreset == device { Image(systemName: "checkmark") }
                                }
                            }
                            .help("\(device.rawValue) — Resolution: \(device.resolutionString)")
                        }
                    } header: {
                        Label(type.rawValue, systemImage: type.iconName)
                    }
                }
            }

            Menu("Category") {
                ForEach(ExtensionCategory.allCases) { cat in
                    Button {
                        store.updateCategory(id: app.id, category: cat)
                    } label: {
                        HStack {
                            Label(cat.rawValue, systemImage: cat.iconName)
                            if app.category == cat { Image(systemName: "checkmark") }
                        }
                    }
                }
            }

            Menu("Companion Browser") {
                ForEach(["Google Chrome", "Safari", "System Default"], id: \.self) { b in
                    Button {
                        store.updateCompanionBrowser(id: app.id, browser: b)
                    } label: {
                        HStack {
                            Text(b)
                            if (app.companionBrowser ?? store.defaultCompanionBrowser) == b {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            if windows.openIDs.contains(app.id) {
                Button("Close Window") { windows.close(id: app.id) }
            }
            Button("Remove", role: .destructive) {
                windows.close(id: app.id)
                store.remove(app)
            }
        }
    }

    // MARK: – Floating slide-up Add App drawer (no layout shift)
    private var addFormDrawer: some View {
        VStack(spacing: 0) {
            // Tap-outside scrim (dismisses drawer)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { isAdding = false }
                }

            // Card itself
            VStack(spacing: 8) {
                // Drag handle indicator
                Capsule()
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 32, height: 3)
                    .padding(.top, 8)

                Text("Add Web App")
                    .font(.system(size: 12, weight: .bold))

                Divider()

                VStack(spacing: 7) {
                    HStack(spacing: 6) {
                        TextField("Name", text: $newName)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        TextField("URL (e.g. m.example.com)", text: $newURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .onSubmit(submitNewApp)
                    }

                    HStack(spacing: 6) {
                        Picker("Category", selection: $newCategory) {
                            ForEach(ExtensionCategory.allCases) { cat in
                                Label(cat.rawValue, systemImage: cat.iconName).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.caption)
                        .frame(maxWidth: .infinity)

                        Picker("Device", selection: $newDevice) {
                            ForEach(DeviceType.allCases) { type in
                                Section(header: Label(type.rawValue, systemImage: type.iconName)) {
                                    ForEach(DevicePreset.devices(for: type)) { device in
                                        Text("\(device.rawValue) (\(device.resolutionString))").tag(device)
                                    }
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }

                    Picker("Companion Browser", selection: $newBrowser) {
                        ForEach(["Google Chrome", "Safari", "System Default"], id: \.self) { b in
                            Text(b).tag(b)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                    .frame(maxWidth: .infinity)

                    if showError {
                        Text("Enter a name and a valid web address.")
                            .font(.caption).foregroundStyle(.red)
                    }

                    HStack(spacing: 8) {
                        Button("Cancel") {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { resetForm() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()

                        Button("Add App", action: submitNewApp)
                            .keyboardShortcut(.defaultAction)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThickMaterial)
                    .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: -4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var footer: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                // Quick Clear Cache
                Button {
                    store.clearAllCookiesAndCache {
                        cacheClearedStatus = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            cacheClearedStatus = false
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: cacheClearedStatus ? "checkmark" : "trash")
                        Text(cacheClearedStatus ? "Cache Cleared" : "Clear Cache")
                    }
                    .font(.system(size: 9.5))
                    .foregroundStyle(cacheClearedStatus ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear all stored cookies, web data, and cache")

                Text("•").foregroundStyle(.quaternary).font(.caption2)

                // Quick Clear History
                Button {
                    store.clearHistory()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Clear History")
                    }
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(store.historyTimeline.isEmpty)
                .help("Clear chronological app launch history")

                Spacer()

                Button {
                    windows.closeAll()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark.circle")
                        Text("Close All (\(windows.instances.count))")
                    }
                    .font(.system(size: 9.5))
                    .foregroundStyle(windows.instances.isEmpty ? Color.secondary.opacity(0.5) : Color.orange)
                }
                .buttonStyle(.plain)
                .disabled(windows.instances.isEmpty)
                .help("Close all open phone windows")

                Text("•").foregroundStyle(.quaternary).font(.caption2)

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
                .buttonStyle(.plain)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
    }

    private var resizeHandleBar: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(isDraggingResize ? Color.accentColor : Color.secondary.opacity(0.4))
                .frame(width: 44, height: 4.5)
                .scaleEffect(isDraggingResize ? 1.08 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isDraggingResize)
            Spacer()
        }
        .frame(height: 14)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if !isDraggingResize {
                        isDraggingResize = true
                        initialDragHeight = menuHeight
                    }
                    let newHeight = initialDragHeight + Double(value.translation.height)
                    let clamped = max(360, min(860, newHeight))
                    if abs(menuHeight - clamped) >= 1.0 {
                        menuHeight = clamped
                    }
                }
                .onEnded { _ in
                    isDraggingResize = false
                }
        )
        .help("Drag vertically to resize menu height")
    }

    private func submitNewApp() {
        if store.add(name: newName, urlString: newURL, companionBrowser: newBrowser, devicePreset: newDevice, category: newCategory) {
            resetForm()
        } else {
            showError = true
        }
    }

    private func resetForm() {
        newName = ""; newURL = ""; showError = false; isAdding = false
    }
}

/// Narrow vertical liquid glass card tile styled with the site's dominant favicon color,
/// corner device viewport picker, and multi-instance badge.
private struct AppTile: View {
    @EnvironmentObject private var store: AppStore
    let app: WebAppConfig
    let openCount: Int
    let onOpen: () -> Void
    let onNewInstance: () -> Void
    let onDeviceChange: (DevicePreset) -> Void

    @State private var hovering = false

    private var dominantColor: Color {
        FaviconService.shared.dominantColor(for: app.host)
    }

    // Extracted to reduce type-checker complexity
    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LinearGradient(
                    colors: [dominantColor.opacity(hovering ? 0.42 : 0.22),
                             dominantColor.opacity(hovering ? 0.18 : 0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(hovering ? 0.22 : 0.14), .clear],
                        startPoint: .top, endPoint: .center))
                    .frame(height: 46)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(LinearGradient(
                colors: [Color.white.opacity(hovering ? 0.7 : 0.45),
                         dominantColor.opacity(hovering ? 0.55 : 0.25),
                         Color.white.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: 1)
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 4.5) {
                // Top row: Instance badge + Device picker
                HStack(spacing: 1.5) {
                    if openCount > 0 {
                        HStack(spacing: 1.5) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 4.5, height: 4.5)
                            if openCount > 1 {
                                Text("\(openCount)")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.green.opacity(0.22)))

                        Button {
                            onNewInstance()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Open another instance")
                    } else if app.isCustom {
                        Image(systemName: "star.fill")
                            .font(.system(size: 6.5))
                            .foregroundStyle(Color.orange)
                    }

                    Spacer()

                    // Corner Device Viewport Button
                    Menu {
                        ForEach(DeviceType.allCases) { type in
                            Section {
                                ForEach(DevicePreset.devices(for: type)) { preset in
                                    Button {
                                        onDeviceChange(preset)
                                    } label: {
                                        HStack {
                                            Label(preset.rawValue, systemImage: preset.iconName)
                                            Spacer()
                                            Text(preset.resolutionString)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            if app.devicePreset == preset {
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
                        HStack(spacing: 1) {
                            Image(systemName: app.devicePreset.iconName)
                                .font(.system(size: 7, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 4.5, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(Color.white.opacity(hovering ? 0.28 : 0.14)))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Device Viewport: \(app.devicePreset.rawValue)")
                }
                .frame(height: 11)

                // Favicon (slightly larger)
                FaviconView(app: app, size: 28)
                    .padding(.top, 2)
                    .shadow(color: dominantColor.opacity(hovering ? 0.5 : 0.25), radius: hovering ? 8 : 3, x: 0, y: hovering ? 3 : 1)

                // App Name & Category badge
                VStack(spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 9.5, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    // Category color pill badge or Play Game badge
                    HStack(spacing: 2) {
                        if app.category == .gaming {
                            Image(systemName: "play.fill")
                                .font(.system(size: 5, weight: .bold))
                        }
                        Text(app.category == .gaming ? "Play" : app.category.shortName)
                            .font(.system(size: 6.5, weight: .semibold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(app.category.color.opacity(0.20)))
                    .foregroundStyle(app.category.color)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(color: dominantColor.opacity(hovering ? 0.45 : 0.15), radius: hovering ? 7 : 3, x: 0, y: hovering ? 3.5 : 1.5)
            .scaleEffect(hovering ? 1.04 : 1.0)
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { hovering = h } }
    }
}

/// Interactive History and Visual Timeline View
private struct HistoryTimelineView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var windows: WindowManager
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("App History & Timeline", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline).bold()
                Spacer()
                if !store.historyTimeline.isEmpty {
                    Button(role: .destructive) {
                        store.clearHistory()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                            Text("Clear")
                        }
                        .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button("Done", action: onClose)
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            if store.historyTimeline.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Recent History")
                        .font(.headline)
                    Text("Apps you launch will appear here in chronological order with their device viewport and launch timestamps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(store.historyTimeline) { item in
                            let targetApp = store.apps.first(where: { $0.id == item.appId }) ?? WebAppConfig(name: item.appName, urlString: item.urlString, devicePreset: item.devicePreset, category: item.category)
                            let dominantColor = FaviconService.shared.dominantColor(for: targetApp.host)

                            HStack(spacing: 8) {
                                // Timeline indicator dot & line
                                VStack(spacing: 2) {
                                    Circle()
                                        .fill(dominantColor)
                                        .frame(width: 7, height: 7)
                                    Rectangle()
                                        .fill(dominantColor.opacity(0.3))
                                        .frame(width: 1.5, height: 26)
                                }
                                .padding(.top, 2)

                                FaviconView(app: targetApp, size: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(item.appName)
                                            .font(.system(size: 11, weight: .semibold))
                                            .lineLimit(1)
                                        Text(timeAgo(item.openedAt))
                                            .font(.system(size: 8.5))
                                            .foregroundStyle(.tertiary)
                                    }

                                    HStack(spacing: 4) {
                                        HStack(spacing: 2) {
                                            Image(systemName: item.devicePreset.iconName)
                                            Text(item.devicePreset.rawValue)
                                        }
                                        .font(.system(size: 8))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1.5)
                                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                                        .foregroundStyle(.secondary)

                                        Text(item.category.rawValue)
                                            .font(.system(size: 8))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Button {
                                    windows.open(targetApp, store: store)
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 7))
                                        Text("Launch")
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                    .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    store.removeHistoryItem(id: item.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Remove from history")
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.2), dominantColor.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                                    )
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 500)
            }
        }
        .padding(.vertical, 2)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}

/// Organized Preferences Tabs
enum PreferencesTab: String, CaseIterable, Identifiable {
    case vpn = "VPN & GPS"
    case accounts = "Accounts"
    case display = "Display"
    case storage = "Storage"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .vpn: return "network.badge.shield.half.filled"
        case .accounts: return "person.crop.circle.badge.plus"
        case .display: return "macwindow"
        case .storage: return "externaldrive"
        }
    }
}

/// Preferences View organized into clean, structured tabs.
private struct PreferencesView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var windows: WindowManager
    @StateObject private var proxy = ProxyService.shared
    let onClose: () -> Void

    @State private var selectedTab: PreferencesTab = .vpn
    @State private var clearedNotification = false

    // Custom VPN with Geolocation form state
    @State private var vpnName = ""
    @State private var vpnHost = "127.0.0.1"
    @State private var vpnPort = "1080"
    @State private var vpnType: ProxyType = .socks5
    @State private var vpnCity = "Chicago"
    @State private var vpnCountryCode = "US"
    @State private var vpnLatString = "41.8781"
    @State private var vpnLonString = "-87.6298"
    @State private var vpnTimezone = "America/Chicago"
    @State private var isDetectingGeo = false
    @State private var geoDetectStatus = ""
    @State private var vpnSaveStatus = ""
    @State private var showCustomVPNForm = false

    // New Persona form state
    @State private var newPersonaName = ""
    @State private var newPersonaEmoji = "💼"
    @State private var newPersonaNote = ""
    @State private var showAddPersonaForm = false

    var body: some View {
        VStack(spacing: 10) {
            // Top Tab Switcher
            Picker("", selection: $selectedTab) {
                ForEach(PreferencesTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 2)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch selectedTab {
                    case .vpn:
                        vpnTabContent
                    case .accounts:
                        accountsTabContent
                    case .display:
                        displayTabContent
                    case .storage:
                        storageTabContent
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 485)

            Divider()

            HStack {
                Spacer()
                Button("Done", action: onClose)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Tab 1: VPN & Location Spoofing
    private var vpnTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "network.badge.shield.half.filled")
                        .foregroundStyle(Color.green)
                    Text("Route Your Own VPN + Geolocation")
                        .font(.subheadline).bold()
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showCustomVPNForm.toggle()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: showCustomVPNForm ? "chevron.up" : "plus.circle.fill")
                            Text(showCustomVPNForm ? "Hide" : "Add VPN")
                        }
                        .font(.system(size: 10.5, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Text("Route PhoneBar through WireGuard, OpenVPN, Tailscale, Shadowsocks, Tor SOCKS5, or SSH tunnel (`ssh -D 1080`), perfectly synchronized with custom GPS coordinates & timezone.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)

                // Saved Custom VPNs List
                if !proxy.customProfiles.isEmpty {
                    VStack(spacing: 5) {
                        ForEach(proxy.customProfiles) { prof in
                            HStack(spacing: 6) {
                                Text(prof.flagEmoji)
                                    .font(.system(size: 14))

                                VStack(alignment: .leading, spacing: 1.5) {
                                    Text(prof.name)
                                        .font(.system(size: 10.5, weight: .bold))
                                    Text("\(prof.proxyType == .socks5 ? "SOCKS5" : "HTTP") • \(prof.defaultProxy.host):\(prof.defaultProxy.port) • \(prof.city) • \(prof.timezone)")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                if proxy.selectedProfile.id == prof.id && (proxy.isProxyEnabled || store.isLocationSpoofingEnabled) {
                                    Text("Active")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundStyle(.green)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.green.opacity(0.14)))
                                } else {
                                    Button("Connect") {
                                        proxy.selectProfile(prof, store: store)
                                    }
                                    .font(.system(size: 9.5))
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }

                                Button {
                                    proxy.deleteCustomProfile(id: prof.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help("Delete custom VPN")
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(proxy.selectedProfile.id == prof.id ? Color.green.opacity(0.08) : Color.primary.opacity(0.04))
                            )
                        }
                    }
                }

                // Add Custom VPN Form
                if showCustomVPNForm || proxy.customProfiles.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Configure Custom VPN & Coordinates")
                            .font(.system(size: 10, weight: .bold))

                        HStack(spacing: 6) {
                            TextField("Name (e.g. WireGuard Chicago)", text: $vpnName)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)

                            Picker("", selection: $vpnType) {
                                Text("SOCKS5").tag(ProxyType.socks5)
                                Text("HTTP").tag(ProxyType.http)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 110)
                        }

                        HStack(spacing: 6) {
                            TextField("Host / IP", text: $vpnHost)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)

                            TextField("Port", text: $vpnPort)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                                .frame(width: 55)
                        }

                        HStack(spacing: 6) {
                            TextField("City (e.g. Chicago)", text: $vpnCity)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)

                            TextField("Country", text: $vpnCountryCode)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                                .frame(width: 55)
                        }

                        HStack(spacing: 6) {
                            TextField("Latitude", text: $vpnLatString)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)

                            TextField("Longitude", text: $vpnLonString)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        }

                        HStack(spacing: 6) {
                            TextField("Timezone", text: $vpnTimezone)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)

                            Menu("Preset TZ") {
                                ForEach(["America/New_York", "America/Chicago", "America/Los_Angeles", "America/Toronto", "Europe/London", "Europe/Paris", "Europe/Berlin", "Europe/Zurich", "Asia/Tokyo", "Asia/Singapore"], id: \.self) { tz in
                                    Button(tz) { vpnTimezone = tz }
                                }
                            }
                            .font(.system(size: 9.5))
                            .fixedSize()
                        }

                        HStack(spacing: 6) {
                            Button {
                                Task {
                                    isDetectingGeo = true
                                    geoDetectStatus = "Testing VPN & detecting geo..."
                                    let port = UInt16(vpnPort.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1080
                                    if let res = await proxy.autoDetectGeolocation(host: vpnHost, port: port, type: vpnType) {
                                        vpnCity = res.city
                                        vpnCountryCode = res.countryCode
                                        vpnLatString = String(format: "%.4f", res.lat)
                                        vpnLonString = String(format: "%.4f", res.lon)
                                        vpnTimezone = res.tz
                                        if vpnName.isEmpty { vpnName = "\(res.city) VPN" }
                                        geoDetectStatus = "✓ Detected: \(res.city), \(res.countryCode) (\(res.ip))"
                                    } else {
                                        geoDetectStatus = "⚠️ Could not connect to VPN endpoint."
                                    }
                                    isDetectingGeo = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if isDetectingGeo { ProgressView().controlSize(.small) }
                                    Image(systemName: "location.magnifyingglass")
                                    Text(isDetectingGeo ? "Detecting..." : "Auto-Detect")
                                }
                                .font(.system(size: 10))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(isDetectingGeo)

                            Spacer()

                            Button("Save & Connect") {
                                let cleanHost = vpnHost.trimmingCharacters(in: .whitespacesAndNewlines)
                                let port = UInt16(vpnPort.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1080
                                let lat = Double(vpnLatString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 40.7128
                                let lon = Double(vpnLonString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -74.0060

                                let prof = proxy.saveCustomVPN(
                                    name: vpnName,
                                    host: cleanHost,
                                    port: port,
                                    type: vpnType,
                                    city: vpnCity,
                                    countryCode: vpnCountryCode,
                                    latitude: lat,
                                    longitude: lon,
                                    timezone: vpnTimezone,
                                    store: store
                                )
                                vpnSaveStatus = "✓ Connected to \(prof.name)!"
                                showCustomVPNForm = false
                            }
                            .font(.system(size: 10, weight: .bold))
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        if !geoDetectStatus.isEmpty {
                            Text(geoDetectStatus)
                                .font(.system(size: 9))
                                .foregroundStyle(geoDetectStatus.starts(with: "✓") ? Color.green : Color.orange)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                }
            }

            Divider()

            // Presets & Public IP Verification
            VStack(alignment: .leading, spacing: 6) {
                Text("Preset Regions & IP Verification")
                    .font(.subheadline).bold()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Public IP:")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text("\(proxy.detectedIP) \(proxy.detectedCountry)")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(proxy.isProxyEnabled ? Color.green : Color.primary)
                    }
                    Spacer()
                    Button("Check IP") {
                        Task { await proxy.checkCurrentIP() }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))

                HStack(spacing: 12) {
                    Toggle("IP Proxy", isOn: $proxy.isProxyEnabled)
                        .font(.caption)
                    Toggle("GPS Spoofing", isOn: $store.isLocationSpoofingEnabled)
                        .font(.caption)
                }

                Picker("Preset Region", selection: Binding(
                    get: { proxy.selectedProfile },
                    set: { proxy.selectProfile($0, store: store) }
                )) {
                    ForEach(SpoofProfile.profiles) { p in
                        Text("\(p.flagEmoji) \(p.name)").tag(p)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
            }
        }
    }

    // MARK: - Tab 2: Accounts & Personas Management
    private var accountsTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.badge.plus")
                    .foregroundStyle(Color.accentColor)
                Text("Account Saving & Personas")
                    .font(.subheadline).bold()
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showAddPersonaForm.toggle()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: showAddPersonaForm ? "chevron.up" : "plus.circle.fill")
                        Text(showAddPersonaForm ? "Hide" : "New Persona")
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Quickly switch identities per site. Anonymous runs an ephemeral session with zero stored cookies, while personas partition independent login tokens.")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)

            // Saved Personas List
            VStack(spacing: 5) {
                ForEach(store.accountProfiles) { profile in
                    HStack(spacing: 7) {
                        Text(profile.avatarEmoji)
                            .font(.system(size: 15))

                        VStack(alignment: .leading, spacing: 1.5) {
                            HStack(spacing: 4) {
                                Text(profile.name)
                                    .font(.system(size: 10.5, weight: .bold))
                                if profile.isAnonymous {
                                    Text("Ephemeral")
                                        .font(.system(size: 7.5, weight: .bold))
                                        .foregroundStyle(.purple)
                                        .padding(.horizontal, 3.5)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.purple.opacity(0.15)))
                                }
                            }
                            Text(profile.note.isEmpty ? (profile.isAnonymous ? "No cookies/history saved" : "Persistent session") : profile.note)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if profile.id != "default" && profile.id != "anonymous" {
                            Button {
                                store.deleteAccountProfile(id: profile.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help("Delete persona")
                        }
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                }
            }

            // Create New Persona Form
            if showAddPersonaForm {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Create New Account Persona")
                        .font(.system(size: 10, weight: .bold))

                    HStack(spacing: 6) {
                        Picker("", selection: $newPersonaEmoji) {
                            ForEach(["👤", "💼", "🛒", "🎭", "🏠", "🔐", "⭐", "🚀", "📱"], id: \.self) { emoji in
                                Text(emoji).tag(emoji)
                            }
                        }
                        .frame(width: 50)
                        .pickerStyle(.menu)

                        TextField("Persona Name (e.g. Work Account)", text: $newPersonaName)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }

                    TextField("Notes (e.g. Used for work tools)", text: $newPersonaNote)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    HStack {
                        Spacer()
                        Button("Add Persona") {
                            store.addAccountProfile(name: newPersonaName, avatarEmoji: newPersonaEmoji, note: newPersonaNote)
                            newPersonaName = ""
                            newPersonaNote = ""
                            showAddPersonaForm = false
                        }
                        .font(.system(size: 10, weight: .bold))
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newPersonaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
            }

            Divider()

            Toggle("Save Persistent Computer Logins", isOn: $store.persistentLoginsEnabled)
                .font(.caption)
        }
    }

    // MARK: - Tab 3: Display & Companion Browser
    private var displayTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Window Display & Pinning")
                .font(.subheadline).bold()

            Toggle("Pin Windows Underneath Menu Bar", isOn: $store.pinUnderMenuBar)
                .font(.caption)

            Toggle("Use Website Favicon as Menu Bar Icon", isOn: $store.useFaviconInMenuBar)
                .font(.caption)

            Toggle("Show Floating Bubble Quick-Access Hub", isOn: $windows.isBubbleHubEnabled)
                .font(.caption)

            Divider()

            Text("App Opening Default Location")
                .font(.subheadline).bold()

            Picker("Default Spawn Location", selection: $store.windowSpawnLocation) {
                Text("Pinned Underneath Companion Menu Bar Icon").tag("underIcon")
                Text("Center of Screen").tag("center")
                Text("Top Right Screen Corner").tag("topRight")
                Text("Top Left Screen Corner").tag("topLeft")
            }
            .pickerStyle(.menu)
            .font(.caption)

            Toggle("Default to Previous Session Window Location", isOn: $store.rememberWindowPosition)
                .font(.caption)

            Text("When enabled, windows will remember the exact place you moved them to. If disabled, new windows always open in your configured default location.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            Divider()

            // Target Monitor / Screen Setting
            VStack(alignment: .leading, spacing: 6) {
                Text("Target Monitor / Display")
                    .font(.subheadline).bold()

                Picker("Open Windows On", selection: $store.targetDisplay) {
                    Text("Display with Mouse Cursor (Dynamic)").tag("cursor")
                    Text("Primary Display (Main Screen)").tag("main")

                    let screens = NSScreen.screens
                    ForEach(0..<screens.count, id: \.self) { idx in
                        let scr = screens[idx]
                        let name = scr.localizedName
                        Text("\(name) [\(Int(scr.frame.width))×\(Int(scr.frame.height))]").tag("screen_\(idx)")
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)

                Text("Choose which monitor PhoneBar apps should spawn onto when opened.")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Bar Color Theme Preferences
            VStack(alignment: .leading, spacing: 6) {
                Text("Bar Color & Appearance")
                    .font(.subheadline).bold()

                Picker("Header & Navigation Color", selection: $store.barThemeColor) {
                    Text("🎨 Dynamic Favicon Match (Default)").tag("favicon")
                    Text("💧 Liquid Glass Neutral").tag("glass")
                    Text("🍎 macOS System Accent").tag("accent")
                    Text("🌌 Deep Indigo").tag("indigo")
                    Text("🌑 Obsidian Dark").tag("obsidian")
                    Text("🌿 Emerald Green").tag("emerald")
                    Text("🍒 Crimson Red").tag("crimson")
                }
                .pickerStyle(.menu)
                .font(.caption)

                Text("Customizes top header and bottom control bar tints across all PhoneBar windows.")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Window Opacity & Transparency Slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Default Window Opacity")
                        .font(.subheadline).bold()
                    Spacer()
                    Text("\(Int(store.globalWindowOpacity * 100))%")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }

                HStack(spacing: 8) {
                    Image(systemName: "circle.dotted")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Slider(value: $store.globalWindowOpacity, in: 0.35...1.0, step: 0.05)
                        .controlSize(.small)

                    Image(systemName: "circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    ForEach([1.0, 0.9, 0.75, 0.6, 0.45], id: \.self) { op in
                        Button("\(Int(op * 100))%") {
                            store.globalWindowOpacity = op
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }

                Text("Control see-through transparency. Individual windows can also toggle Ghost Click-Through under Screen Behaviours (`...`) menu.")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text("Direct Companion Browser Routing")
                .font(.subheadline).bold()

            Text("Set which browser (Chrome, Safari, Default) opens when clicking 'Open in Browser'.")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)

            VStack(spacing: 5) {
                ForEach(store.apps.prefix(10)) { app in
                    HStack {
                        FaviconView(app: app, size: 15)
                        Text(app.name)
                            .font(.caption)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { app.companionBrowser ?? store.defaultCompanionBrowser },
                            set: { store.updateCompanionBrowser(id: app.id, browser: $0) }
                        )) {
                            Text("Chrome").tag("Google Chrome")
                            Text("Safari").tag("Safari")
                            Text("Default").tag("System Default")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .fixedSize()
                    }
                }
            }
        }
    }

    // MARK: - Tab 4: Storage & Privacy
    private var storageTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage & Cache Management")
                .font(.subheadline).bold()

            Button(role: .destructive) {
                store.clearAllCookiesAndCache {
                    clearedNotification = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        clearedNotification = false
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Stored Cookies & Web Cache")
                }
                .font(.caption)
            }

            if clearedNotification {
                Text("✓ Cookies and web cache cleared.")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Divider()

            Text("Ad & Tracker Blocking")
                .font(.subheadline).bold()

            Toggle("Enable Native Content Blocker", isOn: $store.isAdBlockEnabled)
                .font(.caption)

            Text("Blocks advertisements, behavioral trackers, telemetry, and cookie consent overlays using WebKit's native Content Blocker.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            Divider()

            Text("App Launch History")
                .font(.subheadline).bold()

            Button(role: .destructive) {
                store.clearHistory()
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Clear Launch History Timeline (\(store.historyTimeline.count) entries)")
                }
                .font(.caption)
            }
            .disabled(store.historyTimeline.isEmpty)

            Divider()

            Text("Defaults Reset")
                .font(.subheadline).bold()

            Button(role: .destructive) {
                store.resetToDefaults()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset All 70 Preset Apps to Defaults")
                }
                .font(.caption)
            }
        }
    }
}
