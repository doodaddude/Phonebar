import Foundation

public struct ProxyEndpoint: Hashable, Codable {
    public let host: String
    public let port: UInt16
    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }
}

public struct SpoofProfile: Identifiable, Hashable, Codable {
    public let id: String
    public let name: String
    public let countryCode: String
    public let flagEmoji: String
    public let city: String
    public let latitude: Double
    public let longitude: Double
    public let timezone: String
    public let timezoneOffsetMinutes: Int
    public let locale: String
    public let defaultProxy: ProxyEndpoint
    public let backupProxies: [ProxyEndpoint]
    public var proxyType: ProxyType
    public var isCustom: Bool

    public init(id: String? = nil,
                name: String,
                countryCode: String,
                flagEmoji: String,
                city: String,
                latitude: Double,
                longitude: Double,
                timezone: String,
                timezoneOffsetMinutes: Int,
                locale: String,
                defaultProxy: ProxyEndpoint,
                backupProxies: [ProxyEndpoint] = [],
                proxyType: ProxyType = .http,
                isCustom: Bool = false) {
        self.id = id ?? "\(countryCode)_\(city)"
        self.name = name
        self.countryCode = countryCode
        self.flagEmoji = flagEmoji
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
        self.timezoneOffsetMinutes = timezoneOffsetMinutes
        self.locale = locale
        self.defaultProxy = defaultProxy
        self.backupProxies = backupProxies
        self.proxyType = proxyType
        self.isCustom = isCustom
    }

    enum CodingKeys: String, CodingKey {
        case id, name, countryCode, flagEmoji, city
        case latitude, longitude, timezone, timezoneOffsetMinutes, locale
        case defaultProxy, backupProxies, proxyType, isCustom
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        countryCode = try container.decode(String.self, forKey: .countryCode)
        flagEmoji = try container.decode(String.self, forKey: .flagEmoji)
        city = try container.decode(String.self, forKey: .city)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        timezone = try container.decode(String.self, forKey: .timezone)
        timezoneOffsetMinutes = try container.decode(Int.self, forKey: .timezoneOffsetMinutes)
        locale = try container.decode(String.self, forKey: .locale)
        defaultProxy = try container.decode(ProxyEndpoint.self, forKey: .defaultProxy)
        backupProxies = try container.decodeIfPresent([ProxyEndpoint].self, forKey: .backupProxies) ?? []
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(countryCode)_\(city)"
        proxyType = try container.decodeIfPresent(ProxyType.self, forKey: .proxyType) ?? .http
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
    }

    /// Converts a two-letter country code (e.g. "US", "DE") into its regional flag emoji
    public static func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var s = ""
        for v in countryCode.uppercased().unicodeScalars {
            if let scalar = UnicodeScalar(base + v.value) {
                s.unicodeScalars.append(scalar)
            }
        }
        return s.isEmpty ? "🌐" : s
    }

    public static let profiles: [SpoofProfile] = [
        SpoofProfile(
            name: "United States (New York)",
            countryCode: "US",
            flagEmoji: "🇺🇸",
            city: "New York",
            latitude: 40.7128,
            longitude: -74.0060,
            timezone: "America/New_York",
            timezoneOffsetMinutes: 240, // EDT (+4h offset from UTC)
            locale: "en-US",
            defaultProxy: ProxyEndpoint(host: "159.65.230.46", port: 8888),
            backupProxies: [
                ProxyEndpoint(host: "34.43.46.91", port: 80),
                ProxyEndpoint(host: "108.61.29.163", port: 10001),
                ProxyEndpoint(host: "104.225.162.20", port: 8082)
            ]
        ),
        SpoofProfile(
            name: "United Kingdom (London)",
            countryCode: "GB",
            flagEmoji: "🇬🇧",
            city: "London",
            latitude: 51.5074,
            longitude: -0.1278,
            timezone: "Europe/London",
            timezoneOffsetMinutes: -60, // BST
            locale: "en-GB",
            defaultProxy: ProxyEndpoint(host: "185.193.66.52", port: 8080),
            backupProxies: [
                ProxyEndpoint(host: "178.62.24.161", port: 3128),
                ProxyEndpoint(host: "138.68.161.14", port: 3128)
            ]
        ),
        SpoofProfile(
            name: "Canada (Toronto)",
            countryCode: "CA",
            flagEmoji: "🇨🇦",
            city: "Toronto",
            latitude: 43.6532,
            longitude: -79.3832,
            timezone: "America/Toronto",
            timezoneOffsetMinutes: 240, // EDT
            locale: "en-CA",
            defaultProxy: ProxyEndpoint(host: "142.93.130.20", port: 3128),
            backupProxies: [
                ProxyEndpoint(host: "159.203.24.238", port: 3128),
                ProxyEndpoint(host: "144.217.101.242", port: 3128)
            ]
        ),
        SpoofProfile(
            name: "Germany (Frankfurt / Berlin)",
            countryCode: "DE",
            flagEmoji: "🇩🇪",
            city: "Frankfurt",
            latitude: 50.1109,
            longitude: 8.6821,
            timezone: "Europe/Berlin",
            timezoneOffsetMinutes: -120, // CEST
            locale: "de-DE",
            defaultProxy: ProxyEndpoint(host: "159.69.155.19", port: 8080),
            backupProxies: [
                ProxyEndpoint(host: "161.97.164.71", port: 80),
                ProxyEndpoint(host: "116.202.164.71", port: 8080)
            ]
        ),
        SpoofProfile(
            name: "France (Paris)",
            countryCode: "FR",
            flagEmoji: "🇫🇷",
            city: "Paris",
            latitude: 48.8566,
            longitude: 2.3522,
            timezone: "Europe/Paris",
            timezoneOffsetMinutes: -120,
            locale: "fr-FR",
            defaultProxy: ProxyEndpoint(host: "51.159.115.233", port: 3128),
            backupProxies: [
                ProxyEndpoint(host: "51.75.147.42", port: 3128)
            ]
        ),
        SpoofProfile(
            name: "Japan (Tokyo)",
            countryCode: "JP",
            flagEmoji: "🇯🇵",
            city: "Tokyo",
            latitude: 35.6762,
            longitude: 139.6503,
            timezone: "Asia/Tokyo",
            timezoneOffsetMinutes: -540, // JST
            locale: "ja-JP",
            defaultProxy: ProxyEndpoint(host: "133.18.234.13", port: 8080),
            backupProxies: [
                ProxyEndpoint(host: "160.16.81.168", port: 8080)
            ]
        )
    ]
}
