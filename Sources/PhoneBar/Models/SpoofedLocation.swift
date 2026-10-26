import Foundation

public struct SpoofedLocation: Identifiable, Hashable, Codable {
    public var id: String { name }
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let countryCode: String
    public let flagEmoji: String
    public var timezone: String
    public var timezoneOffsetMinutes: Int
    public var locale: String
    public var isCustomVPN: Bool

    public init(name: String,
                latitude: Double,
                longitude: Double,
                countryCode: String,
                flagEmoji: String,
                timezone: String = "America/New_York",
                timezoneOffsetMinutes: Int = 240,
                locale: String = "en-US",
                isCustomVPN: Bool = false) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.countryCode = countryCode
        self.flagEmoji = flagEmoji
        self.timezone = timezone
        self.timezoneOffsetMinutes = timezoneOffsetMinutes
        self.locale = locale
        self.isCustomVPN = isCustomVPN
    }

    enum CodingKeys: String, CodingKey {
        case name, latitude, longitude, countryCode, flagEmoji
        case timezone, timezoneOffsetMinutes, locale, isCustomVPN
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        countryCode = try container.decode(String.self, forKey: .countryCode)
        flagEmoji = try container.decode(String.self, forKey: .flagEmoji)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone) ?? "America/New_York"
        timezoneOffsetMinutes = try container.decodeIfPresent(Int.self, forKey: .timezoneOffsetMinutes) ?? 240
        locale = try container.decodeIfPresent(String.self, forKey: .locale) ?? "en-US"
        isCustomVPN = try container.decodeIfPresent(Bool.self, forKey: .isCustomVPN) ?? false
    }

    public static let realLocation = SpoofedLocation(
        name: "Real Location (Off)",
        latitude: 0.0,
        longitude: 0.0,
        countryCode: "REAL",
        flagEmoji: "📍",
        timezone: "America/New_York",
        timezoneOffsetMinutes: 240,
        locale: "en-US"
    )

    public static let presets: [SpoofedLocation] = [
        SpoofedLocation(name: "New York, USA", latitude: 40.7128, longitude: -74.0060, countryCode: "US", flagEmoji: "🇺🇸", timezone: "America/New_York", timezoneOffsetMinutes: 240, locale: "en-US"),
        SpoofedLocation(name: "San Francisco, USA", latitude: 37.7749, longitude: -122.4194, countryCode: "US", flagEmoji: "🇺🇸", timezone: "America/Los_Angeles", timezoneOffsetMinutes: 420, locale: "en-US"),
        SpoofedLocation(name: "Toronto, Canada", latitude: 43.6532, longitude: -79.3832, countryCode: "CA", flagEmoji: "🇨🇦", timezone: "America/Toronto", timezoneOffsetMinutes: 240, locale: "en-CA"),
        SpoofedLocation(name: "London, UK", latitude: 51.5074, longitude: -0.1278, countryCode: "GB", flagEmoji: "🇬🇧", timezone: "Europe/London", timezoneOffsetMinutes: -60, locale: "en-GB"),
        SpoofedLocation(name: "Paris, France", latitude: 48.8566, longitude: 2.3522, countryCode: "FR", flagEmoji: "🇫🇷", timezone: "Europe/Paris", timezoneOffsetMinutes: -120, locale: "fr-FR"),
        SpoofedLocation(name: "Tokyo, Japan", latitude: 35.6762, longitude: 139.6503, countryCode: "JP", flagEmoji: "🇯🇵", timezone: "Asia/Tokyo", timezoneOffsetMinutes: -540, locale: "ja-JP"),
        SpoofedLocation(name: "Berlin, Germany", latitude: 52.5200, longitude: 13.4050, countryCode: "DE", flagEmoji: "🇩🇪", timezone: "Europe/Berlin", timezoneOffsetMinutes: -120, locale: "de-DE"),
        SpoofedLocation(name: "Singapore", latitude: 1.3521, longitude: 103.8198, countryCode: "SG", flagEmoji: "🇸🇬", timezone: "Asia/Singapore", timezoneOffsetMinutes: -480, locale: "en-SG"),
        SpoofedLocation(name: "Sydney, Australia", latitude: -33.8688, longitude: 151.2093, countryCode: "AU", flagEmoji: "🇦🇺", timezone: "Australia/Sydney", timezoneOffsetMinutes: -600, locale: "en-AU")
    ]
}
