import Foundation

/// Configuration for one launchable web app.
public struct WebAppConfig: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var symbolName: String
    public var urlString: String
    /// Optional per-app override. Falls back to the selected device UA.
    public var userAgent: String?
    /// Selected device viewport preset.
    public var devicePreset: DevicePreset
    /// Companion browser to open in (e.g., "Google Chrome", "Safari").
    public var companionBrowser: String?
    /// Category grouping for organization.
    public var category: ExtensionCategory
    /// Whether the app was added/customized by the user.
    public var isCustom: Bool

    public init(id: String = UUID().uuidString,
                name: String,
                symbolName: String = "globe",
                urlString: String,
                userAgent: String? = nil,
                devicePreset: DevicePreset = .iPhoneMini,
                companionBrowser: String? = nil,
                category: ExtensionCategory = .productivityAndNotes,
                isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.urlString = urlString
        self.userAgent = userAgent
        self.devicePreset = devicePreset
        self.companionBrowser = companionBrowser
        self.category = category
        self.isCustom = isCustom
    }

    public var url: URL? { URL(string: urlString) }

    public var host: String {
        url?.host ?? urlString
    }

    public var resolvedUserAgent: String {
        if let userAgent = userAgent, !userAgent.isEmpty {
            return userAgent
        }
        return devicePreset.userAgent
    }

    enum CodingKeys: String, CodingKey {
        case id, name, symbolName, urlString, userAgent, devicePreset, companionBrowser, category, isCustom
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName) ?? "globe"
        urlString = try container.decode(String.self, forKey: .urlString)
        userAgent = try container.decodeIfPresent(String.self, forKey: .userAgent)
        devicePreset = try container.decodeIfPresent(DevicePreset.self, forKey: .devicePreset) ?? .iPhoneMini
        companionBrowser = try container.decodeIfPresent(String.self, forKey: .companionBrowser)
        category = try container.decodeIfPresent(ExtensionCategory.self, forKey: .category) ?? Self.inferCategory(for: name, url: urlString)
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
    }

    public static func inferCategory(for name: String, url: String) -> ExtensionCategory {
        let text = (name + " " + url).lowercased()

        if text.contains("gemini") || text.contains("chatgpt") || text.contains("claude") || text.contains("perplexity") || text.contains("github") || text.contains("stack") || text.contains("deepl") {
            return .aiAndDev
        }
        if text.contains("amazon") || text.contains("aliexpress") || text.contains("ebay") || text.contains("temu") || text.contains("etsy") || text.contains("walmart") || text.contains("target") || text.contains("bestbuy") {
            return .globalShopping
        }
        if text.contains("skip") || text.contains("uber eats") || text.contains("doordash") || text.contains("instacart") || text.contains("grubhub") || text.contains("yelp") {
            return .foodAndDelivery
        }
        if text.contains("twitter") || text.contains("x.com") || text.contains("reddit") || text.contains("instagram") || text.contains("threads") || text.contains("discord") || text.contains("whatsapp") || text.contains("linkedin") || text.contains("pinterest") {
            return .socialMedia
        }
        if text.contains("youtube") || text.contains("twitch") || text.contains("spotify") || text.contains("netflix") || text.contains("soundcloud") || text.contains("music") || text.contains("ted") {
            return .streamingAndAudio
        }
        if text.contains("news") || text.contains("bbc") || text.contains("reuters") || text.contains("cnn") || text.contains("techcrunch") || text.contains("verge") || text.contains("bloomberg") || text.contains("wikipedia") {
            return .newsAndMedia
        }
        if text.contains("maps") || text.contains("airbnb") || text.contains("booking") || text.contains("tripadvisor") || text.contains("flight") {
            return .travelAndMaps
        }
        if text.contains("finance") || text.contains("crypto") || text.contains("coin") || text.contains("trading") || text.contains("paypal") || text.contains("robinhood") || text.contains("marketwatch") || text.contains("wealthsimple") || text.contains("square") || text.contains("rbc") || text.contains("td") || text.contains("scotia") || text.contains("bmo") || text.contains("cibc") || text.contains("questrade") || text.contains("shopify") {
            return .financeAndCrypto
        }
        if text.contains("game") || text.contains("2048") || text.contains("wordle") || text.contains("chess") || text.contains("lichess") || text.contains("sudoku") || text.contains("minesweeper") || text.contains("solitaire") || text.contains("tetris") || text.contains("pacman") || text.contains("steam") || text.contains("ign") || text.contains("roblox") || text.contains("poki") {
            return .gaming
        }
        if text.contains("espn") || text.contains("sports") || text.contains("flashscore") || text.contains("sofascore") || text.contains("strava") || text.contains("nhl") || text.contains("nba") || text.contains("nfl") || text.contains("mlb") || text.contains("formula1") || text.contains("tsn") {
            return .sports
        }
        return .productivityAndNotes
    }

    /// Full library of categorized default apps
    public static var defaults: [WebAppConfig] {
        presetExtensionsLibrary.map { $0.toWebAppConfig() }
    }
}
