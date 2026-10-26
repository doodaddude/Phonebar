import AppKit
import Foundation
import WebKit

public struct AppHistoryItem: Identifiable, Codable, Hashable {
    public let id: String
    public let appId: String
    public let appName: String
    public let urlString: String
    public let devicePreset: DevicePreset
    public let category: ExtensionCategory
    public let openedAt: Date

    public init(id: String = UUID().uuidString,
                appId: String,
                appName: String,
                urlString: String,
                devicePreset: DevicePreset,
                category: ExtensionCategory,
                openedAt: Date = Date()) {
        self.id = id
        self.appId = appId
        self.appName = appName
        self.urlString = urlString
        self.devicePreset = devicePreset
        self.category = category
        self.openedAt = openedAt
    }
}

/// Owns the list of apps and app preferences, recently opened list, and location spoofing.
@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var apps: [WebAppConfig]
    @Published private(set) var recentlyOpenedIDs: [String] = []
    @Published private(set) var historyTimeline: [AppHistoryItem] = []
    @Published var accountProfiles: [AccountProfile] = []

    // Preferences
    @Published var pinUnderMenuBar: Bool {
        didSet { UserDefaults.standard.set(pinUnderMenuBar, forKey: "PhoneBar.pinUnderMenuBar") }
    }
    @Published var useFaviconInMenuBar: Bool {
        didSet { UserDefaults.standard.set(useFaviconInMenuBar, forKey: "PhoneBar.useFaviconInMenuBar") }
    }
    @Published var persistentLoginsEnabled: Bool {
        didSet { UserDefaults.standard.set(persistentLoginsEnabled, forKey: "PhoneBar.persistentLoginsEnabled") }
    }
    @Published var defaultCompanionBrowser: String {
        didSet { UserDefaults.standard.set(defaultCompanionBrowser, forKey: "PhoneBar.defaultCompanionBrowser") }
    }

    // Window Spawning & Positioning Preferences
    @Published var rememberWindowPosition: Bool {
        didSet { UserDefaults.standard.set(rememberWindowPosition, forKey: "PhoneBar.rememberWindowPosition") }
    }
    @Published var windowSpawnLocation: String {
        didSet { UserDefaults.standard.set(windowSpawnLocation, forKey: "PhoneBar.windowSpawnLocation") }
    }
    @Published var targetDisplay: String {
        didSet { UserDefaults.standard.set(targetDisplay, forKey: "PhoneBar.targetDisplay") }
    }

    // Appearance, Colors & Opacity Preferences
    @Published var barThemeColor: String {
        didSet {
            UserDefaults.standard.set(barThemeColor, forKey: "PhoneBar.barThemeColor")
            NotificationCenter.default.post(name: .appearanceSettingsChanged, object: nil)
        }
    }
    @Published var globalWindowOpacity: Double {
        didSet {
            UserDefaults.standard.set(globalWindowOpacity, forKey: "PhoneBar.globalWindowOpacity")
            NotificationCenter.default.post(name: .appearanceSettingsChanged, object: nil)
        }
    }

    // Global Force Dark Mode for all apps
    @Published var globalForceDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(globalForceDarkMode, forKey: "PhoneBar.globalForceDarkMode")
            NotificationCenter.default.post(name: .globalForceDarkModeChanged, object: nil, userInfo: ["enabled": globalForceDarkMode])
        }
    }

    // Local Location Spoofing
    @Published var isLocationSpoofingEnabled: Bool {
        didSet { UserDefaults.standard.set(isLocationSpoofingEnabled, forKey: "PhoneBar.locationSpoofingEnabled") }
    }
    @Published var selectedSpoofedLocation: SpoofedLocation {
        didSet {
            if let data = try? JSONEncoder().encode(selectedSpoofedLocation) {
                UserDefaults.standard.set(data, forKey: "PhoneBar.spoofedLocation")
            }
        }
    }

    // Ad Blocking
    @Published var isAdBlockEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAdBlockEnabled, forKey: "PhoneBar.adBlockEnabled")
            AdBlockService.shared.isEnabled = isAdBlockEnabled
        }
    }

    private let appsDefaultsKey = "PhoneBar.apps.v3"
    private let legacyV2Key = "PhoneBar.apps.v2"
    private let legacyV1Key = "PhoneBar.apps.v1"
    private let recentKey = "PhoneBar.recentlyOpenedIDs"
    private let historyKey = "PhoneBar.historyTimeline"
    private let profilesKey = "PhoneBar.accountProfiles.v1"

    init() {
        self.pinUnderMenuBar = UserDefaults.standard.object(forKey: "PhoneBar.pinUnderMenuBar") as? Bool ?? true
        self.useFaviconInMenuBar = UserDefaults.standard.object(forKey: "PhoneBar.useFaviconInMenuBar") as? Bool ?? true
        self.persistentLoginsEnabled = UserDefaults.standard.object(forKey: "PhoneBar.persistentLoginsEnabled") as? Bool ?? true
        self.defaultCompanionBrowser = UserDefaults.standard.string(forKey: "PhoneBar.defaultCompanionBrowser") ?? "Google Chrome"
        self.rememberWindowPosition = UserDefaults.standard.object(forKey: "PhoneBar.rememberWindowPosition") as? Bool ?? true
        self.windowSpawnLocation = UserDefaults.standard.string(forKey: "PhoneBar.windowSpawnLocation") ?? "underIcon"
        self.globalForceDarkMode = UserDefaults.standard.bool(forKey: "PhoneBar.globalForceDarkMode")

        self.isLocationSpoofingEnabled = UserDefaults.standard.bool(forKey: "PhoneBar.locationSpoofingEnabled")
        if let locData = UserDefaults.standard.data(forKey: "PhoneBar.spoofedLocation"),
           let loc = try? JSONDecoder().decode(SpoofedLocation.self, from: locData) {
            self.selectedSpoofedLocation = loc
        } else {
            self.selectedSpoofedLocation = SpoofedLocation.presets[0] // New York
        }

        let adBlock = UserDefaults.standard.object(forKey: "PhoneBar.adBlockEnabled") as? Bool ?? true
        self.isAdBlockEnabled = adBlock
        AdBlockService.shared.isEnabled = adBlock

        self.targetDisplay = UserDefaults.standard.string(forKey: "PhoneBar.targetDisplay") ?? "cursor"
        self.barThemeColor = UserDefaults.standard.string(forKey: "PhoneBar.barThemeColor") ?? "favicon"
        self.globalWindowOpacity = UserDefaults.standard.object(forKey: "PhoneBar.globalWindowOpacity") as? Double ?? 1.0

        self.recentlyOpenedIDs = UserDefaults.standard.stringArray(forKey: recentKey) ?? []

        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([AppHistoryItem].self, from: data) {
            self.historyTimeline = history
        }

        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let saved = try? JSONDecoder().decode([AccountProfile].self, from: data),
           !saved.isEmpty {
            self.accountProfiles = saved
        } else {
            self.accountProfiles = AccountProfile.defaultProfiles
        }

        var loadedApps: [WebAppConfig] = []
        if let data = UserDefaults.standard.data(forKey: appsDefaultsKey),
           let saved = try? JSONDecoder().decode([WebAppConfig].self, from: data),
           !saved.isEmpty {
            loadedApps = saved
        } else if let data = UserDefaults.standard.data(forKey: legacyV2Key),
                  let saved = try? JSONDecoder().decode([WebAppConfig].self, from: data),
                  !saved.isEmpty {
            loadedApps = saved
        } else if let data = UserDefaults.standard.data(forKey: legacyV1Key),
                  let saved = try? JSONDecoder().decode([WebAppConfig].self, from: data),
                  !saved.isEmpty {
            loadedApps = saved
        } else {
            loadedApps = WebAppConfig.defaults
        }

        // Ensure all loaded apps have proper categories
        for i in 0..<loadedApps.count {
            if loadedApps[i].category == .productivityAndNotes {
                loadedApps[i].category = WebAppConfig.inferCategory(for: loadedApps[i].name, url: loadedApps[i].urlString)
            }
        }

        // Tag initial core favorites as custom if none marked yet
        let starterIDs: Set<String> = ["gemini", "amazon", "aliexpress", "skipthedishes", "chatgpt", "youtube"]
        let hasCustom = loadedApps.contains(where: { $0.isCustom })
        if !hasCustom {
            for i in 0..<loadedApps.count {
                if starterIDs.contains(loadedApps[i].id) {
                    loadedApps[i].isCustom = true
                }
            }
        }

        // Merge any new library presets that aren't in the list yet
        var existingNames = Set(loadedApps.map { $0.name.lowercased() })
        var existingURLs = Set(loadedApps.map { $0.urlString.lowercased() })
        for preset in presetExtensionsLibrary {
            if !existingNames.contains(preset.name.lowercased()) && !existingURLs.contains(preset.urlString.lowercased()) {
                loadedApps.append(preset.toWebAppConfig())
                existingNames.insert(preset.name.lowercased())
                existingURLs.insert(preset.urlString.lowercased())
            }
        }

        self.apps = loadedApps
        persist()
    }

    // MARK: - Section Filters

    /// Apps that the user added or explicitly favorited (shown at the very top)
    var myAddedApps: [WebAppConfig] {
        apps.filter { $0.isCustom }
    }

    /// Apps opened recently (shown right below Added apps)
    var recentlyOpenedApps: [WebAppConfig] {
        let appMap = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        return recentlyOpenedIDs.compactMap { appMap[$0] }
    }

    /// Suggested apps from the library (below recently opened)
    var suggestedApps: [WebAppConfig] {
        let addedIDs = Set(myAddedApps.map { $0.id })
        let recentIDs = Set(recentlyOpenedIDs)
        return apps.filter { !addedIDs.contains($0.id) && !recentIDs.contains($0.id) }
    }

    func recordAppOpened(_ id: String) {
        var recents = recentlyOpenedIDs.filter { $0 != id }
        recents.insert(id, at: 0)
        if recents.count > 12 {
            recents = Array(recents.prefix(12))
        }
        self.recentlyOpenedIDs = recents
        UserDefaults.standard.set(recents, forKey: recentKey)

        if let app = apps.first(where: { $0.id == id }) {
            recordHistory(for: app)
        }
    }

    func recordHistory(for app: WebAppConfig) {
        let item = AppHistoryItem(
            appId: app.id,
            appName: app.name,
            urlString: app.urlString,
            devicePreset: app.devicePreset,
            category: app.category,
            openedAt: Date()
        )
        var timeline = historyTimeline
        timeline.insert(item, at: 0)
        if timeline.count > 50 {
            timeline = Array(timeline.prefix(50))
        }
        self.historyTimeline = timeline
        if let data = try? JSONEncoder().encode(timeline) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func clearHistory() {
        self.historyTimeline = []
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    func removeHistoryItem(id: String) {
        historyTimeline.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(historyTimeline) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    // MARK: - Account Profile Management

    func addAccountProfile(name: String, avatarEmoji: String = "👤", note: String = "") {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let newProf = AccountProfile(name: cleanName, avatarEmoji: avatarEmoji, note: note)
        accountProfiles.append(newProf)
        persistProfiles()
    }

    func deleteAccountProfile(id: String) {
        guard id != "default" && id != "anonymous" else { return }
        accountProfiles.removeAll { $0.id == id }
        persistProfiles()
    }

    func persistProfiles() {
        if let data = try? JSONEncoder().encode(accountProfiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
    }

    // MARK: - App Management

    @discardableResult
    func add(name: String, urlString: String, companionBrowser: String? = nil, devicePreset: DevicePreset = .iPhoneMini, category: ExtensionCategory? = nil) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !raw.isEmpty else { return false }
        if !raw.contains("://") { raw = "https://" + raw }
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, host.contains(".") else { return false }

        let resolvedCat = category ?? WebAppConfig.inferCategory(for: cleanName, url: raw)
        let newApp = WebAppConfig(
            name: cleanName,
            urlString: url.absoluteString,
            devicePreset: devicePreset,
            companionBrowser: companionBrowser ?? defaultCompanionBrowser,
            category: resolvedCat,
            isCustom: true // user-added apps are marked as custom
        )
        // Add at the beginning of custom apps
        apps.insert(newApp, at: 0)
        persist()
        return true
    }

    func toggleCustom(id: String) {
        if let idx = apps.firstIndex(where: { $0.id == id }) {
            apps[idx].isCustom.toggle()
            persist()
        }
    }

    func update(app: WebAppConfig) {
        if let idx = apps.firstIndex(where: { $0.id == app.id }) {
            apps[idx] = app
            persist()
        }
    }

    func updateDevice(id: String, device: DevicePreset) {
        if let idx = apps.firstIndex(where: { $0.id == id }) {
            apps[idx].devicePreset = device
            persist()
        }
    }

    func updateCategory(id: String, category: ExtensionCategory) {
        if let idx = apps.firstIndex(where: { $0.id == id }) {
            apps[idx].category = category
            persist()
        }
    }

    func updateCompanionBrowser(id: String, browser: String?) {
        if let idx = apps.firstIndex(where: { $0.id == id }) {
            apps[idx].companionBrowser = browser
            persist()
        }
    }

    func remove(_ app: WebAppConfig) {
        apps.removeAll { $0.id == app.id }
        recentlyOpenedIDs.removeAll { $0 == app.id }
        UserDefaults.standard.set(recentlyOpenedIDs, forKey: recentKey)
        persist()
    }

    func resetToDefaults() {
        apps = WebAppConfig.defaults
        recentlyOpenedIDs = []
        UserDefaults.standard.set(recentlyOpenedIDs, forKey: recentKey)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(data, forKey: appsDefaultsKey)
        }
    }

    // MARK: - Cookie / Session Management

    func clearAllCookiesAndCache(completion: @escaping () -> Void) {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.fetchDataRecords(ofTypes: types) { records in
            dataStore.removeData(ofTypes: types, for: records) {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    // MARK: - Companion Browser Launch

    func openInBrowser(app: WebAppConfig, preferredBrowser: String? = nil) {
        guard let url = app.url else { return }
        let browser = preferredBrowser ?? app.companionBrowser ?? defaultCompanionBrowser

        let bundleID: String? = {
            switch browser.lowercased() {
            case let b where b.contains("chrome"):
                return "com.google.Chrome"
            case let b where b.contains("safari"):
                return "com.apple.Safari"
            case let b where b.contains("firefox"):
                return "org.mozilla.firefox"
            case let b where b.contains("edge"):
                return "com.microsoft.edgemac"
            case let b where b.contains("brave"):
                return "com.brave.Browser"
            case let b where b.contains("arc"):
                return "company.thebrowser.Browser"
            default:
                return nil
            }
        }()

        if let bundleID = bundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config, completionHandler: nil)
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}

extension Notification.Name {
    static let globalForceDarkModeChanged = Notification.Name("PhoneBar.globalForceDarkModeChanged")
    static let appearanceSettingsChanged = Notification.Name("PhoneBar.appearanceSettingsChanged")
}

