import Foundation
import Network
import WebKit

public enum ProxyType: String, CaseIterable, Identifiable, Codable {
    case http = "HTTP / HTTPS"
    case socks5 = "SOCKS5"
    public var id: String { rawValue }
}

public struct FreeProxyItem: Identifiable, Hashable, Codable {
    public var id: String { "\(host):\(port)" }
    public var name: String
    public var host: String
    public var port: UInt16
    public var type: ProxyType
    public var countryCode: String
    public var flagEmoji: String

    public init(name: String, host: String, port: UInt16, type: ProxyType = .http, countryCode: String = "US", flagEmoji: String = "🇺🇸") {
        self.name = name
        self.host = host
        self.port = port
        self.type = type
        self.countryCode = countryCode
        self.flagEmoji = flagEmoji
    }

    public static let presets: [FreeProxyItem] = [
        FreeProxyItem(name: "US Fast Cloud", host: "159.65.230.46", port: 8888, type: .http, countryCode: "US", flagEmoji: "🇺🇸"),
        FreeProxyItem(name: "US Public #2", host: "34.43.46.91", port: 80, type: .http, countryCode: "US", flagEmoji: "🇺🇸"),
        FreeProxyItem(name: "UK Public", host: "185.193.66.52", port: 8080, type: .http, countryCode: "GB", flagEmoji: "🇬🇧"),
        FreeProxyItem(name: "Canada Public", host: "142.93.130.20", port: 3128, type: .http, countryCode: "CA", flagEmoji: "🇨🇦"),
        FreeProxyItem(name: "Germany Public", host: "159.69.155.19", port: 8080, type: .http, countryCode: "DE", flagEmoji: "🇩🇪"),
        FreeProxyItem(name: "France Public", host: "51.159.115.233", port: 3128, type: .http, countryCode: "FR", flagEmoji: "🇫🇷"),
        FreeProxyItem(name: "Japan Public", host: "133.18.234.13", port: 8080, type: .http, countryCode: "JP", flagEmoji: "🇯🇵"),
        FreeProxyItem(name: "Local Tor Proxy", host: "127.0.0.1", port: 9050, type: .socks5, countryCode: "TOR", flagEmoji: "🧅"),
        FreeProxyItem(name: "Tor Browser Proxy", host: "127.0.0.1", port: 9150, type: .socks5, countryCode: "TOR", flagEmoji: "🧅")
    ]
}

@MainActor
public final class ProxyService: ObservableObject {
    public static let shared = ProxyService()

    @Published public var isProxyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isProxyEnabled, forKey: "PhoneBar.isProxyEnabled")
            applyConfiguration()
        }
    }

    @Published public var currentProxy: FreeProxyItem {
        didSet {
            if let data = try? JSONEncoder().encode(currentProxy) {
                UserDefaults.standard.set(data, forKey: "PhoneBar.currentProxy")
            }
            if isProxyEnabled {
                applyConfiguration()
            }
        }
    }

    @Published public var selectedProfile: SpoofProfile {
        didSet {
            if let data = try? JSONEncoder().encode(selectedProfile) {
                UserDefaults.standard.set(data, forKey: "PhoneBar.selectedProfile")
            }
        }
    }

    @Published public var autoSyncGeoWithIP: Bool {
        didSet {
            UserDefaults.standard.set(autoSyncGeoWithIP, forKey: "PhoneBar.autoSyncGeoWithIP")
        }
    }

    @Published public var customHost: String {
        didSet { UserDefaults.standard.set(customHost, forKey: "PhoneBar.customProxyHost") }
    }

    @Published public var customPortString: String {
        didSet { UserDefaults.standard.set(customPortString, forKey: "PhoneBar.customProxyPort") }
    }

    @Published public var customType: ProxyType = .http

    @Published public var customProfiles: [SpoofProfile] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(customProfiles) {
                UserDefaults.standard.set(data, forKey: "PhoneBar.customProfiles")
            }
        }
    }

    public var allProfiles: [SpoofProfile] {
        customProfiles + SpoofProfile.profiles
    }

    @Published public var detectedIP: String = "Checking..."
    @Published public var detectedCountry: String = ""
    @Published public var isCheckingIP: Bool = false
    @Published public var isFetchingProxies: Bool = false
    @Published public var liveProxies: [FreeProxyItem] = []

    private var currentBackupIndex: Int = 0

    private init() {
        self.isProxyEnabled = UserDefaults.standard.bool(forKey: "PhoneBar.isProxyEnabled")
        self.autoSyncGeoWithIP = UserDefaults.standard.object(forKey: "PhoneBar.autoSyncGeoWithIP") as? Bool ?? true
        self.customHost = UserDefaults.standard.string(forKey: "PhoneBar.customProxyHost") ?? ""
        self.customPortString = UserDefaults.standard.string(forKey: "PhoneBar.customProxyPort") ?? "8080"

        if let profData = UserDefaults.standard.data(forKey: "PhoneBar.customProfiles"),
           let list = try? JSONDecoder().decode([SpoofProfile].self, from: profData) {
            self.customProfiles = list
        }

        if let profData = UserDefaults.standard.data(forKey: "PhoneBar.selectedProfile"),
           let savedProf = try? JSONDecoder().decode(SpoofProfile.self, from: profData) {
            self.selectedProfile = savedProf
        } else {
            self.selectedProfile = SpoofProfile.profiles[0]
        }

        if let data = UserDefaults.standard.data(forKey: "PhoneBar.currentProxy"),
           let saved = try? JSONDecoder().decode(FreeProxyItem.self, from: data) {
            self.currentProxy = saved
        } else {
            self.currentProxy = FreeProxyItem.presets[0]
        }

        applyConfiguration()
        Task {
            await self.checkCurrentIP()
        }
    }

    public func applyConfiguration() {
        if #available(macOS 14.0, *) {
            let store = WKWebsiteDataStore.default()
            if isProxyEnabled {
                let endpointHost = NWEndpoint.Host(currentProxy.host)
                let endpointPort = NWEndpoint.Port(rawValue: currentProxy.port) ?? 8080
                let endpoint = NWEndpoint.hostPort(host: endpointHost, port: endpointPort)

                let config: ProxyConfiguration
                if currentProxy.type == .socks5 {
                    config = ProxyConfiguration(socksv5Proxy: endpoint)
                } else {
                    config = ProxyConfiguration(httpCONNECTProxy: endpoint)
                }
                store.proxyConfigurations = [config]
            } else {
                store.proxyConfigurations = []
            }
        }
    }

    /// Selects a unified profile and automatically synchronizes IP and Geo
    func selectProfile(_ profile: SpoofProfile, store: AppStore? = nil) {
        self.selectedProfile = profile
        self.currentBackupIndex = 0
        self.currentProxy = FreeProxyItem(
            name: "\(profile.name)",
            host: profile.defaultProxy.host,
            port: profile.defaultProxy.port,
            type: profile.proxyType,
            countryCode: profile.countryCode,
            flagEmoji: profile.flagEmoji
        )
        self.isProxyEnabled = true

        if autoSyncGeoWithIP, let store = store {
            store.selectedSpoofedLocation = SpoofedLocation(
                name: "\(profile.city), \(profile.countryCode)",
                latitude: profile.latitude,
                longitude: profile.longitude,
                countryCode: profile.countryCode,
                flagEmoji: profile.flagEmoji,
                timezone: profile.timezone,
                timezoneOffsetMinutes: profile.timezoneOffsetMinutes,
                locale: profile.locale,
                isCustomVPN: profile.isCustom
            )
            store.isLocationSpoofingEnabled = true
        }

        applyConfiguration()

        Task {
            await self.checkCurrentIP()
        }
    }

    /// Saves and connects to a custom user-defined VPN / Proxy route with matching Geolocation
    @discardableResult
    func saveCustomVPN(name: String,
                       host: String,
                       port: UInt16,
                       type: ProxyType,
                       city: String,
                       countryCode: String,
                       latitude: Double,
                       longitude: Double,
                       timezone: String,
                       locale: String = "en-US",
                       store: AppStore? = nil) -> SpoofProfile {
        let flag = SpoofProfile.flagEmoji(for: countryCode)
        let tz = TimeZone(identifier: timezone) ?? TimeZone.current
        let offsetMinutes = -Int(tz.secondsFromGMT() / 60)

        let profileName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(city) VPN"
            : name.trimmingCharacters(in: .whitespacesAndNewlines)

        let newProfile = SpoofProfile(
            id: UUID().uuidString,
            name: profileName,
            countryCode: countryCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines),
            flagEmoji: flag,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: latitude,
            longitude: longitude,
            timezone: timezone.trimmingCharacters(in: .whitespacesAndNewlines),
            timezoneOffsetMinutes: offsetMinutes,
            locale: locale,
            defaultProxy: ProxyEndpoint(host: host.trimmingCharacters(in: .whitespacesAndNewlines), port: port),
            backupProxies: [],
            proxyType: type,
            isCustom: true
        )

        customProfiles.removeAll { $0.id == newProfile.id }
        customProfiles.append(newProfile)
        selectProfile(newProfile, store: store)
        return newProfile
    }

    /// Deletes a custom user-defined VPN profile
    func deleteCustomProfile(id: String) {
        customProfiles.removeAll { $0.id == id }
        if selectedProfile.id == id {
            if let first = customProfiles.first {
                selectProfile(first)
            } else {
                selectProfile(SpoofProfile.profiles[0])
            }
        }
    }

    /// Auto-detects public IP and exact geolocation (City, Coordinates, Timezone) from the VPN or current connection
    public func autoDetectGeolocation(host: String? = nil, port: UInt16? = nil, type: ProxyType? = nil) async -> (city: String, countryCode: String, flag: String, lat: Double, lon: Double, tz: String, ip: String)? {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 6.0
        sessionConfig.timeoutIntervalForResource = 8.0

        if let h = host?.trimmingCharacters(in: .whitespacesAndNewlines), !h.isEmpty, let p = port {
            var proxyDict: [AnyHashable: Any] = [:]
            if (type ?? .http) == .socks5 {
                proxyDict[kCFStreamPropertySOCKSProxyHost as String] = h
                proxyDict[kCFStreamPropertySOCKSProxyPort as String] = Int(p)
            } else {
                proxyDict[kCFNetworkProxiesHTTPEnable as String] = 1
                proxyDict[kCFNetworkProxiesHTTPProxy as String] = h
                proxyDict[kCFNetworkProxiesHTTPPort as String] = Int(p)
                proxyDict[kCFNetworkProxiesHTTPSEnable as String] = 1
                proxyDict[kCFNetworkProxiesHTTPSProxy as String] = h
                proxyDict[kCFNetworkProxiesHTTPSPort as String] = Int(p)
            }
            sessionConfig.connectionProxyDictionary = proxyDict
        } else if isProxyEnabled {
            var proxyDict: [AnyHashable: Any] = [:]
            if currentProxy.type == .socks5 {
                proxyDict[kCFStreamPropertySOCKSProxyHost as String] = currentProxy.host
                proxyDict[kCFStreamPropertySOCKSProxyPort as String] = Int(currentProxy.port)
            } else {
                proxyDict[kCFNetworkProxiesHTTPEnable as String] = 1
                proxyDict[kCFNetworkProxiesHTTPProxy as String] = currentProxy.host
                proxyDict[kCFNetworkProxiesHTTPPort as String] = Int(currentProxy.port)
                proxyDict[kCFNetworkProxiesHTTPSEnable as String] = 1
                proxyDict[kCFNetworkProxiesHTTPSProxy as String] = currentProxy.host
                proxyDict[kCFNetworkProxiesHTTPSPort as String] = Int(currentProxy.port)
            }
            sessionConfig.connectionProxyDictionary = proxyDict
        }

        let session = URLSession(configuration: sessionConfig)

        // Try ip-api.com first
        if let url = URL(string: "http://ip-api.com/json/?fields=status,countryCode,city,lat,lon,timezone,query") {
            do {
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String, status == "success" {
                    let city = (json["city"] as? String) ?? "Unknown City"
                    let countryCode = (json["countryCode"] as? String) ?? "US"
                    let lat = (json["lat"] as? Double) ?? 0.0
                    let lon = (json["lon"] as? Double) ?? 0.0
                    let tz = (json["timezone"] as? String) ?? "America/New_York"
                    let ip = (json["query"] as? String) ?? ""
                    let flag = SpoofProfile.flagEmoji(for: countryCode)
                    return (city: city, countryCode: countryCode, flag: flag, lat: lat, lon: lon, tz: tz, ip: ip)
                }
            } catch {
                // fall through to ipwho.is
            }
        }

        // Secondary fallback: ipwho.is
        if let url = URL(string: "https://ipwho.is/") {
            do {
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success {
                    let city = (json["city"] as? String) ?? "Unknown City"
                    let countryCode = (json["country_code"] as? String) ?? "US"
                    let lat = (json["latitude"] as? Double) ?? 0.0
                    let lon = (json["longitude"] as? Double) ?? 0.0
                    let tzDict = json["timezone"] as? [String: Any]
                    let tz = (tzDict?["id"] as? String) ?? "America/New_York"
                    let ip = (json["ip"] as? String) ?? ""
                    let flag = SpoofProfile.flagEmoji(for: countryCode)
                    return (city: city, countryCode: countryCode, flag: flag, lat: lat, lon: lon, tz: tz, ip: ip)
                }
            } catch {
                // ignore
            }
        }

        return nil
    }

    /// Rotates to the next backup proxy within the same country
    public func rotateToNextBackupProxy() {
        let allEndpoints = [selectedProfile.defaultProxy] + selectedProfile.backupProxies
        guard !allEndpoints.isEmpty else { return }

        currentBackupIndex = (currentBackupIndex + 1) % allEndpoints.count
        let next = allEndpoints[currentBackupIndex]

        self.currentProxy = FreeProxyItem(
            name: "\(selectedProfile.name) #\(currentBackupIndex + 1)",
            host: next.host,
            port: next.port,
            type: selectedProfile.proxyType,
            countryCode: selectedProfile.countryCode,
            flagEmoji: selectedProfile.flagEmoji
        )
        self.isProxyEnabled = true

        Task {
            await self.checkCurrentIP()
        }
    }

    public func setProxy(_ proxy: FreeProxyItem) {
        self.currentProxy = proxy
        self.isProxyEnabled = true
        Task {
            await self.checkCurrentIP()
        }
    }

    public func applyCustomProxy() {
        let cleanHost = customHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPort = UInt16(customPortString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 8080
        guard !cleanHost.isEmpty else { return }

        let customItem = FreeProxyItem(
            name: "Custom (\(cleanHost):\(cleanPort))",
            host: cleanHost,
            port: cleanPort,
            type: customType,
            countryCode: "CUSTOM",
            flagEmoji: "🌐"
        )
        setProxy(customItem)
    }

    public func checkCurrentIP() async {
        isCheckingIP = true
        defer { isCheckingIP = false }

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 6.0

        if isProxyEnabled {
            var proxyDict: [AnyHashable: Any] = [:]
            if currentProxy.type == .socks5 {
                proxyDict[kCFStreamPropertySOCKSProxyHost as String] = currentProxy.host
                proxyDict[kCFStreamPropertySOCKSProxyPort as String] = Int(currentProxy.port)
            } else {
                proxyDict[kCFNetworkProxiesHTTPEnable as String] = 1
                proxyDict[kCFNetworkProxiesHTTPProxy as String] = currentProxy.host
                proxyDict[kCFNetworkProxiesHTTPPort as String] = Int(currentProxy.port)
                proxyDict[kCFNetworkProxiesHTTPSEnable as String] = 1
                proxyDict[kCFNetworkProxiesHTTPSProxy as String] = currentProxy.host
                proxyDict[kCFNetworkProxiesHTTPSPort as String] = Int(currentProxy.port)
            }
            sessionConfig.connectionProxyDictionary = proxyDict
        }

        let session = URLSession(configuration: sessionConfig)
        guard let url = URL(string: "https://ipinfo.io/json") else { return }

        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ip = json["ip"] as? String {
                let country = (json["country"] as? String) ?? ""
                let city = (json["city"] as? String) ?? ""
                self.detectedIP = ip
                self.detectedCountry = city.isEmpty ? country : "\(city), \(country)"
            }
        } catch {
            // Fallback to ipify
            if let ipifyURL = URL(string: "https://api.ipify.org?format=json"),
               let (data, _) = try? await session.data(from: ipifyURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ip = json["ip"] as? String {
                self.detectedIP = ip
                self.detectedCountry = ""
            } else {
                if self.isProxyEnabled {
                    self.detectedIP = "\(self.currentProxy.host) (Active)"
                } else {
                    self.detectedIP = "Direct Connection"
                }
            }
        }
    }

    public func fetchFreshFreeProxies() async {
        isFetchingProxies = true
        defer { isFetchingProxies = false }

        guard let url = URL(string: "https://api.proxyscrape.com/v2/?request=displayproxies&protocol=http&timeout=2000&country=all&ssl=yes&anonymity=elite") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let str = String(data: data, encoding: .utf8) {
                let lines = str.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && $0.contains(":") }

                var results: [FreeProxyItem] = []
                for (idx, line) in lines.prefix(12).enumerated() {
                    let parts = line.components(separatedBy: ":")
                    if parts.count == 2, let port = UInt16(parts[1]) {
                        results.append(FreeProxyItem(
                            name: "Live Proxy #\(idx + 1)",
                            host: parts[0],
                            port: port,
                            type: .http,
                            countryCode: "LIVE",
                            flagEmoji: "⚡️"
                        ))
                    }
                }
                self.liveProxies = results
            }
        } catch {
            // ignore
        }
    }
}
