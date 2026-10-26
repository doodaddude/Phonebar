import Foundation
import SwiftUI

public enum ExtensionCategory: String, CaseIterable, Identifiable, Codable {
    case aiAndDev = "AI & Developer Tools"
    case socialMedia = "Social & Messaging"
    case globalShopping = "Global Shopping"
    case newsAndMedia = "News & Media"
    case streamingAndAudio = "Streaming & Audio"
    case foodAndDelivery = "Food & Delivery"
    case travelAndMaps = "Travel & Maps"
    case financeAndCrypto = "Finance & Business"
    case productivityAndNotes = "Productivity & Workspace"
    case sports = "Sports & Fitness"
    case gaming = "Gaming & Play"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .aiAndDev: return "brain.head.profile"
        case .socialMedia: return "bubble.left.and.bubble.right"
        case .globalShopping: return "cart"
        case .newsAndMedia: return "newspaper"
        case .streamingAndAudio: return "play.rectangle"
        case .foodAndDelivery: return "fork.knife"
        case .travelAndMaps: return "map"
        case .financeAndCrypto: return "chart.xyaxis.line"
        case .productivityAndNotes: return "square.grid.2x2"
        case .sports: return "sportscourt"
        case .gaming: return "gamecontroller.fill"
        }
    }

    public var shortName: String {
        switch self {
        case .aiAndDev: return "AI"
        case .socialMedia: return "Social"
        case .globalShopping: return "Shop"
        case .newsAndMedia: return "News"
        case .streamingAndAudio: return "Media"
        case .foodAndDelivery: return "Food"
        case .travelAndMaps: return "Travel"
        case .financeAndCrypto: return "Finance"
        case .productivityAndNotes: return "Work"
        case .sports: return "Sports"
        case .gaming: return "Games"
        }
    }

    public var color: Color {
        switch self {
        case .aiAndDev: return Color.purple
        case .socialMedia: return Color.blue
        case .globalShopping: return Color.orange
        case .newsAndMedia: return Color.red
        case .streamingAndAudio: return Color.pink
        case .foodAndDelivery: return Color(red: 1.0, green: 0.58, blue: 0.0)
        case .travelAndMaps: return Color.teal
        case .financeAndCrypto: return Color.green
        case .productivityAndNotes: return Color.indigo
        case .sports: return Color(red: 0.15, green: 0.65, blue: 0.95)
        case .gaming: return Color(red: 0.0, green: 0.85, blue: 0.65)
        }
    }
}

public struct PresetExtension: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let urlString: String
    public let iconName: String
    public let category: ExtensionCategory
    public let defaultBrowser: String?

    public init(name: String, urlString: String, iconName: String, category: ExtensionCategory, defaultBrowser: String? = nil) {
        self.name = name
        self.urlString = urlString
        self.iconName = iconName
        self.category = category
        self.defaultBrowser = defaultBrowser
    }

    public func toWebAppConfig() -> WebAppConfig {
        let cleanID = name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: "&", with: "and")
        return WebAppConfig(
            id: cleanID,
            name: name,
            symbolName: iconName,
            urlString: urlString,
            devicePreset: .iPhoneMini,
            companionBrowser: defaultBrowser ?? (category == .globalShopping || category == .foodAndDelivery ? "Safari" : "Google Chrome"),
            category: category
        )
    }
}

// Global Library — 300 Quick-Add Web Extensions Across 11 Specialized Categories
public let presetExtensionsLibrary: [PresetExtension] = [

    // MARK: - 1. Finance & Canadian Business (32)
    PresetExtension(name: "Wealthsimple",    urlString: "https://my.wealthsimple.com/app/login",  iconName: "chart.line.uptrend.xyaxis",  category: .financeAndCrypto),
    PresetExtension(name: "Shopify",         urlString: "https://www.shopify.com",                iconName: "bag.badge.plus",             category: .financeAndCrypto),
    PresetExtension(name: "Square",          urlString: "https://squareup.com/dashboard",         iconName: "square.fill",                category: .financeAndCrypto),
    PresetExtension(name: "Stripe",          urlString: "https://dashboard.stripe.com",          iconName: "creditcard.and.123",         category: .financeAndCrypto),
    PresetExtension(name: "RBC Online",      urlString: "https://www.rbcroyalbank.com",          iconName: "building.columns.fill",      category: .financeAndCrypto),
    PresetExtension(name: "TD Bank",         urlString: "https://www.td.com",                    iconName: "building.columns",           category: .financeAndCrypto),
    PresetExtension(name: "Scotiabank",      urlString: "https://www.scotiabank.com",            iconName: "dollarsign.arrow.circlepath", category: .financeAndCrypto),
    PresetExtension(name: "BMO Bank",        urlString: "https://www.bmo.com",                   iconName: "banknote",                   category: .financeAndCrypto),
    PresetExtension(name: "CIBC Online",     urlString: "https://www.cibc.com",                  iconName: "building.2.crop.circle",     category: .financeAndCrypto),
    PresetExtension(name: "Tangerine",       urlString: "https://www.tangerine.ca",              iconName: "circle.circle.fill",         category: .financeAndCrypto),
    PresetExtension(name: "Questrade",       urlString: "https://my.questrade.com",              iconName: "arrow.triangle.swap",        category: .financeAndCrypto),
    PresetExtension(name: "PayPal",          urlString: "https://www.paypal.com",                iconName: "creditcard",                 category: .financeAndCrypto),
    PresetExtension(name: "Yahoo Finance",   urlString: "https://finance.yahoo.com",             iconName: "chart.xyaxis.line",          category: .financeAndCrypto),
    PresetExtension(name: "TradingView",     urlString: "https://www.tradingview.com",           iconName: "waveform.path.ecg",          category: .financeAndCrypto),
    PresetExtension(name: "Robinhood",       urlString: "https://robinhood.com",                 iconName: "leaf",                       category: .financeAndCrypto),
    PresetExtension(name: "CoinMarketCap",   urlString: "https://coinmarketcap.com",             iconName: "bitcoinsign.circle",         category: .financeAndCrypto),
    PresetExtension(name: "CoinGecko",       urlString: "https://www.coingecko.com",             iconName: "chart.bar.fill",             category: .financeAndCrypto),
    PresetExtension(name: "Coinbase",        urlString: "https://www.coinbase.com",              iconName: "c.circle.fill",              category: .financeAndCrypto),
    PresetExtension(name: "Binance",         urlString: "https://www.binance.com",               iconName: "b.circle.fill",              category: .financeAndCrypto),
    PresetExtension(name: "Kraken",          urlString: "https://www.kraken.com",                iconName: "network",                    category: .financeAndCrypto),
    PresetExtension(name: "Revolut Web",     urlString: "https://app.revolut.com",               iconName: "r.circle.fill",              category: .financeAndCrypto),
    PresetExtension(name: "Wise",            urlString: "https://wise.com",                      iconName: "arrow.left.arrow.right",     category: .financeAndCrypto),
    PresetExtension(name: "QuickBooks",      urlString: "https://qbo.intuit.com",                iconName: "doc.text.fill",              category: .financeAndCrypto),
    PresetExtension(name: "Wave Accounting", urlString: "https://my.waveapps.com",               iconName: "water.waves",                category: .financeAndCrypto),
    PresetExtension(name: "FreshBooks",      urlString: "https://my.freshbooks.com",             iconName: "leaf.circle.fill",           category: .financeAndCrypto),
    PresetExtension(name: "MarketWatch",     urlString: "https://www.marketwatch.com",           iconName: "chart.bar",                  category: .financeAndCrypto),
    PresetExtension(name: "Investopedia",    urlString: "https://www.investopedia.com",          iconName: "books.vertical",             category: .financeAndCrypto),
    PresetExtension(name: "Seeking Alpha",   urlString: "https://seekingalpha.com",              iconName: "magnifyingglass.circle.fill", category: .financeAndCrypto),
    PresetExtension(name: "Finviz",          urlString: "https://finviz.com",                    iconName: "chart.pie.fill",             category: .financeAndCrypto),
    PresetExtension(name: "Etherscan",       urlString: "https://etherscan.io",                  iconName: "point.3.filled.connected.trianglepath.dotted", category: .financeAndCrypto),
    PresetExtension(name: "Uniswap",         urlString: "https://app.uniswap.org",               iconName: "arrow.triangle.2.circlepath", category: .financeAndCrypto),
    PresetExtension(name: "OpenSea",         urlString: "https://opensea.io",                    iconName: "seal",                       category: .financeAndCrypto),

    // MARK: - 2. Gaming & Interactive Play (30)
    PresetExtension(name: "2048 Game",       urlString: "https://play2048.co",                   iconName: "square.grid.2x2.fill",       category: .gaming),
    PresetExtension(name: "Wordle",          urlString: "https://www.nytimes.com/games/wordle",  iconName: "character.square.fill",      category: .gaming),
    PresetExtension(name: "Chess.com",       urlString: "https://www.chess.com",                 iconName: "crown.fill",                 category: .gaming),
    PresetExtension(name: "Lichess",         urlString: "https://lichess.org",                   iconName: "shield.checkerboard",        category: .gaming),
    PresetExtension(name: "Sudoku Online",   urlString: "https://sudoku.com",                    iconName: "number.square.fill",         category: .gaming),
    PresetExtension(name: "Minesweeper",     urlString: "https://minesweeperonline.com",         iconName: "flag.fill",                  category: .gaming),
    PresetExtension(name: "Solitaire Bliss", urlString: "https://www.solitairebliss.com",        iconName: "suit.spade.fill",            category: .gaming),
    PresetExtension(name: "Tetris Web",      urlString: "https://tetris.com/play-tetris",        iconName: "square.split.diagonal.2x2",  category: .gaming),
    PresetExtension(name: "Pac-Man",         urlString: "https://www.google.com/logos/2010/pacman/pacman10-hp.html", iconName: "circle.circle.fill", category: .gaming),
    PresetExtension(name: "Crossword Solver", urlString: "https://www.boatloadpuzzles.com/playcrossword", iconName: "pencil.line",       category: .gaming),
    PresetExtension(name: "GeoGuessr",       urlString: "https://www.geoguessr.com",             iconName: "globe.badge.chevron.backward", category: .gaming),
    PresetExtension(name: "Steam Community", urlString: "https://steamcommunity.com",            iconName: "desktopcomputer",            category: .gaming),
    PresetExtension(name: "Twitch Gaming",   urlString: "https://m.twitch.tv/directory/game",    iconName: "gamecontroller.fill",        category: .gaming),
    PresetExtension(name: "IGN",             urlString: "https://www.ign.com",                   iconName: "flame.circle.fill",          category: .gaming),
    PresetExtension(name: "Polygon",         urlString: "https://www.polygon.com",               iconName: "hexagon.fill",               category: .gaming),
    PresetExtension(name: "Kotaku",          urlString: "https://kotaku.com",                    iconName: "k.circle.fill",              category: .gaming),
    PresetExtension(name: "Speedrun.com",    urlString: "https://www.speedrun.com",              iconName: "hare.fill",                  category: .gaming),
    PresetExtension(name: "Roblox Web",      urlString: "https://www.roblox.com",                iconName: "cube.fill",                  category: .gaming),
    PresetExtension(name: "CrazyGames",      urlString: "https://www.crazygames.com",            iconName: "sparkles",                   category: .gaming),
    PresetExtension(name: "Poki Games",      urlString: "https://poki.com",                      iconName: "dice.fill",                  category: .gaming),
    PresetExtension(name: "Armor Games",     urlString: "https://armorgames.com",                iconName: "shield.fill",                category: .gaming),
    PresetExtension(name: "Kongregate",      urlString: "https://www.kongregate.com",            iconName: "k.square.fill",              category: .gaming),
    PresetExtension(name: "Newgrounds",      urlString: "https://www.newgrounds.com",            iconName: "n.circle.fill",              category: .gaming),
    PresetExtension(name: "Itch.io",         urlString: "https://itch.io",                       iconName: "gamecontroller",             category: .gaming),
    PresetExtension(name: "Board Game Arena", urlString: "https://boardgamearena.com",           iconName: "table.furniture.fill",       category: .gaming),
    PresetExtension(name: "Skribbl.io",      urlString: "https://skribbl.io",                    iconName: "pencil.tip.crop.circle",     category: .gaming),
    PresetExtension(name: "Slither.io",      urlString: "http://slither.io",                     iconName: "circle.grid.cross.fill",     category: .gaming),
    PresetExtension(name: "Agar.io",         urlString: "https://agar.io",                       iconName: "circle.fill",                category: .gaming),
    PresetExtension(name: "Krunker",         urlString: "https://krunker.io",                    iconName: "target",                     category: .gaming),
    PresetExtension(name: "Xbox Cloud",      urlString: "https://www.xbox.com/play",             iconName: "logo.xbox",                  category: .gaming),

    // MARK: - 3. Sports & Fitness (26)
    PresetExtension(name: "ESPN",            urlString: "https://www.espn.com",                  iconName: "sportscourt.fill",           category: .sports),
    PresetExtension(name: "Flashscore",      urlString: "https://www.flashscore.com",            iconName: "timer",                      category: .sports),
    PresetExtension(name: "Sofascore",       urlString: "https://www.sofascore.com",             iconName: "chart.bar.doc.horizontal",   category: .sports),
    PresetExtension(name: "Sportsnet",       urlString: "https://www.sportsnet.ca",              iconName: "s.circle.fill",              category: .sports),
    PresetExtension(name: "TSN Canada",      urlString: "https://www.tsn.ca",                    iconName: "t.circle.fill",              category: .sports),
    PresetExtension(name: "NHL",             urlString: "https://www.nhl.com",                   iconName: "hockey.puck.fill",           category: .sports),
    PresetExtension(name: "NBA",             urlString: "https://www.nba.com",                   iconName: "basketball.fill",            category: .sports),
    PresetExtension(name: "NFL",             urlString: "https://www.nfl.com",                   iconName: "football.fill",              category: .sports),
    PresetExtension(name: "MLB",             urlString: "https://www.mlb.com",                   iconName: "baseball.fill",              category: .sports),
    PresetExtension(name: "Formula 1",       urlString: "https://www.formula1.com",              iconName: "steeringwheel",              category: .sports),
    PresetExtension(name: "BBC Sport",       urlString: "https://www.bbc.com/sport",             iconName: "figure.soccer",              category: .sports),
    PresetExtension(name: "Sky Sports",      urlString: "https://www.skysports.com",             iconName: "cloud.sun.fill",             category: .sports),
    PresetExtension(name: "The Athletic",    urlString: "https://theathletic.com",               iconName: "newspaper.fill",             category: .sports),
    PresetExtension(name: "Strava",          urlString: "https://www.strava.com",                iconName: "figure.run",                 category: .sports),
    PresetExtension(name: "AllTrails",       urlString: "https://www.alltrails.com",             iconName: "figure.hiking",              category: .sports),
    PresetExtension(name: "Fitbit Dashboard", urlString: "https://www.fitbit.com",               iconName: "heart.fill",                 category: .sports),
    PresetExtension(name: "Garmin Connect",  urlString: "https://connect.garmin.com",            iconName: "gauge.with.needle",          category: .sports),
    PresetExtension(name: "Cricbuzz",        urlString: "https://www.cricbuzz.com",              iconName: "circle.circle",              category: .sports),
    PresetExtension(name: "UEFA",            urlString: "https://www.uefa.com",                  iconName: "trophy.fill",                category: .sports),
    PresetExtension(name: "Premier League",  urlString: "https://www.premierleague.com",         iconName: "crown",                      category: .sports),
    PresetExtension(name: "UFC",             urlString: "https://www.ufc.com",                   iconName: "figure.boxing",              category: .sports),
    PresetExtension(name: "Bleacher Report", urlString: "https://bleacherreport.com",            iconName: "b.square.fill",              category: .sports),
    PresetExtension(name: "WhoScored",       urlString: "https://www.whoscored.com",             iconName: "chart.line.uptrend.xyaxis",  category: .sports),
    PresetExtension(name: "Golf Digest",     urlString: "https://www.golfdigest.com",            iconName: "figure.golf",                category: .sports),
    PresetExtension(name: "Tennis.com",      urlString: "https://www.tennis.com",                iconName: "tennisball.fill",            category: .sports),
    PresetExtension(name: "CBC Sports",      urlString: "https://www.cbc.ca/sports",             iconName: "play.tv.fill",               category: .sports),

    // MARK: - 4. AI & Developer Tools (28)
    PresetExtension(name: "ChatGPT",         urlString: "https://chatgpt.com",                    iconName: "brain.head.profile",         category: .aiAndDev),
    PresetExtension(name: "Google Gemini",   urlString: "https://gemini.google.com",              iconName: "sparkles",                   category: .aiAndDev),
    PresetExtension(name: "Claude AI",       urlString: "https://claude.ai",                      iconName: "cpu",                        category: .aiAndDev),
    PresetExtension(name: "Perplexity",      urlString: "https://www.perplexity.ai",              iconName: "magnifyingglass.circle",     category: .aiAndDev),
    PresetExtension(name: "GitHub",          urlString: "https://github.com/mobile",              iconName: "terminal",                   category: .aiAndDev),
    PresetExtension(name: "Stack Overflow",  urlString: "https://stackoverflow.com",              iconName: "layers",                     category: .aiAndDev),
    PresetExtension(name: "DeepL",           urlString: "https://www.deepl.com/translator",       iconName: "character.book.closed",      category: .aiAndDev),
    PresetExtension(name: "Mistral AI",      urlString: "https://chat.mistral.ai",                iconName: "wind",                       category: .aiAndDev),
    PresetExtension(name: "Grok",            urlString: "https://grok.com",                       iconName: "wand.and.stars",             category: .aiAndDev),
    PresetExtension(name: "Hugging Face",    urlString: "https://huggingface.co",                 iconName: "face.smiling",               category: .aiAndDev),
    PresetExtension(name: "Replit",          urlString: "https://replit.com",                     iconName: "chevron.left.forwardslash.chevron.right", category: .aiAndDev),
    PresetExtension(name: "CodePen",         urlString: "https://codepen.io",                     iconName: "pencil.and.outline",         category: .aiAndDev),
    PresetExtension(name: "GitLab",          urlString: "https://gitlab.com",                     iconName: "chevron.left.slash.chevron.right", category: .aiAndDev),
    PresetExtension(name: "Vercel",          urlString: "https://vercel.com",                     iconName: "triangle",                   category: .aiAndDev),
    PresetExtension(name: "Cloudflare",      urlString: "https://dash.cloudflare.com",            iconName: "cloud",                      category: .aiAndDev),
    PresetExtension(name: "Google Colab",    urlString: "https://colab.research.google.com",      iconName: "doc.text.below.ecg",         category: .aiAndDev),
    PresetExtension(name: "Phind",           urlString: "https://www.phind.com",                  iconName: "magnifyingglass.circle.fill", category: .aiAndDev),
    PresetExtension(name: "You.com",         urlString: "https://you.com",                        iconName: "person.circle",              category: .aiAndDev),
    PresetExtension(name: "Poe",             urlString: "https://poe.com",                        iconName: "bubble.left.fill",           category: .aiAndDev),
    PresetExtension(name: "Devv.ai",         urlString: "https://devv.ai",                        iconName: "hammer.circle",              category: .aiAndDev),
    PresetExtension(name: "OpenRouter",      urlString: "https://openrouter.ai/chat",             iconName: "arrow.triangle.swap",        category: .aiAndDev),
    PresetExtension(name: "Cursor Docs",     urlString: "https://docs.cursor.com",                iconName: "arrow.up.right.diamond",     category: .aiAndDev),
    PresetExtension(name: "MDN Web Docs",    urlString: "https://developer.mozilla.org",          iconName: "book.pages",                 category: .aiAndDev),
    PresetExtension(name: "Postman Web",     urlString: "https://web.postman.co",                 iconName: "paperplane.circle.fill",     category: .aiAndDev),
    PresetExtension(name: "npm",             urlString: "https://www.npmjs.com",                  iconName: "shippingbox.fill",           category: .aiAndDev),
    PresetExtension(name: "PyPI",            urlString: "https://pypi.org",                       iconName: "cube.box.fill",              category: .aiAndDev),
    PresetExtension(name: "Supabase",        urlString: "https://supabase.com/dashboard",         iconName: "bolt.badge.clock",           category: .aiAndDev),
    PresetExtension(name: "Firebase",        urlString: "https://console.firebase.google.com",   iconName: "flame.circle",               category: .aiAndDev),

    // MARK: - 5. Social & Messaging (26)
    PresetExtension(name: "X / Twitter",     urlString: "https://m.x.com",                       iconName: "bubble.left.and.bubble.right", category: .socialMedia),
    PresetExtension(name: "Threads",         urlString: "https://www.threads.net",               iconName: "at",                         category: .socialMedia),
    PresetExtension(name: "Reddit",          urlString: "https://m.reddit.com",                  iconName: "person.3",                   category: .socialMedia),
    PresetExtension(name: "Instagram",       urlString: "https://www.instagram.com",             iconName: "camera",                     category: .socialMedia),
    PresetExtension(name: "LinkedIn",        urlString: "https://www.linkedin.com",              iconName: "briefcase",                  category: .socialMedia),
    PresetExtension(name: "Pinterest",       urlString: "https://www.pinterest.com",             iconName: "pin",                        category: .socialMedia),
    PresetExtension(name: "Discord",         urlString: "https://discord.com/app",               iconName: "message",                    category: .socialMedia),
    PresetExtension(name: "WhatsApp Web",    urlString: "https://web.whatsapp.com",              iconName: "phone.bubble",               category: .socialMedia),
    PresetExtension(name: "Telegram Web",    urlString: "https://web.telegram.org",              iconName: "paperplane.fill",            category: .socialMedia),
    PresetExtension(name: "Facebook",        urlString: "https://m.facebook.com",                iconName: "f.circle",                   category: .socialMedia),
    PresetExtension(name: "Mastodon",        urlString: "https://mastodon.social",               iconName: "tusk",                       category: .socialMedia),
    PresetExtension(name: "Bluesky",         urlString: "https://bsky.app",                      iconName: "cloud.fill",                 category: .socialMedia),
    PresetExtension(name: "TikTok",          urlString: "https://www.tiktok.com",                iconName: "music.note.tv",              category: .socialMedia),
    PresetExtension(name: "Snapchat",        urlString: "https://web.snapchat.com",              iconName: "camera.viewfinder",          category: .socialMedia),
    PresetExtension(name: "Tumblr",          urlString: "https://www.tumblr.com",                iconName: "t.circle",                   category: .socialMedia),
    PresetExtension(name: "Quora",           urlString: "https://www.quora.com",                 iconName: "questionmark.circle",        category: .socialMedia),
    PresetExtension(name: "Medium",          urlString: "https://medium.com",                    iconName: "m.circle",                   category: .socialMedia),
    PresetExtension(name: "Substack",        urlString: "https://substack.com",                  iconName: "envelope.badge",             category: .socialMedia),
    PresetExtension(name: "Signal Web",      urlString: "https://signal.me",                     iconName: "lock.shield",                category: .socialMedia),
    PresetExtension(name: "Slack",           urlString: "https://app.slack.com",                 iconName: "number",                     category: .socialMedia),
    PresetExtension(name: "WeChat Web",      urlString: "https://wx.qq.com",                     iconName: "bubble.left.and.text.bubble.right", category: .socialMedia),
    PresetExtension(name: "Nextdoor",        urlString: "https://nextdoor.com",                  iconName: "house.and.flag",             category: .socialMedia),
    PresetExtension(name: "BeReal",          urlString: "https://bereal.com",                    iconName: "camera.macro",               category: .socialMedia),
    PresetExtension(name: "VKontakte",       urlString: "https://m.vk.com",                      iconName: "v.square",                   category: .socialMedia),
    PresetExtension(name: "Line Web",        urlString: "https://line.me",                       iconName: "bubble.middle.bottom",       category: .socialMedia),
    PresetExtension(name: "KakaoTalk",       urlString: "https://www.kakaocorp.com",             iconName: "message.badge",              category: .socialMedia),

    // MARK: - 6. Global & Canadian Shopping (26)
    PresetExtension(name: "Amazon",          urlString: "https://www.amazon.com",                iconName: "cart",                       category: .globalShopping),
    PresetExtension(name: "Amazon Canada",   urlString: "https://www.amazon.ca",                 iconName: "cart.fill",                  category: .globalShopping),
    PresetExtension(name: "Canadian Tire",   urlString: "https://www.canadiantire.ca",           iconName: "triangle.fill",              category: .globalShopping),
    PresetExtension(name: "AliExpress",      urlString: "https://m.aliexpress.com",              iconName: "bag",                        category: .globalShopping),
    PresetExtension(name: "eBay",            urlString: "https://m.ebay.com",                    iconName: "tag",                        category: .globalShopping),
    PresetExtension(name: "Temu",            urlString: "https://www.temu.com",                  iconName: "basket",                     category: .globalShopping),
    PresetExtension(name: "Etsy",            urlString: "https://www.etsy.com",                  iconName: "gift",                       category: .globalShopping),
    PresetExtension(name: "Walmart",         urlString: "https://www.walmart.com",               iconName: "building.2",                 category: .globalShopping),
    PresetExtension(name: "Target",          urlString: "https://www.target.com",                iconName: "target",                     category: .globalShopping),
    PresetExtension(name: "Best Buy",        urlString: "https://www.bestbuy.com",               iconName: "tv",                         category: .globalShopping),
    PresetExtension(name: "Best Buy Canada", urlString: "https://www.bestbuy.ca",                iconName: "tv.fill",                    category: .globalShopping),
    PresetExtension(name: "Costco Canada",   urlString: "https://www.costco.ca",                 iconName: "cube.box",                   category: .globalShopping),
    PresetExtension(name: "Shein",           urlString: "https://www.shein.com",                 iconName: "tshirt",                     category: .globalShopping),
    PresetExtension(name: "ASOS",            urlString: "https://www.asos.com",                  iconName: "hanger",                     category: .globalShopping),
    PresetExtension(name: "Lululemon",       urlString: "https://shop.lululemon.com",            iconName: "figure.walk",                category: .globalShopping),
    PresetExtension(name: "Aritzia",         urlString: "https://www.aritzia.com",               iconName: "sparkles",                   category: .globalShopping),
    PresetExtension(name: "Roots Canada",    urlString: "https://www.roots.com",                 iconName: "leaf.arrow.circlepath",      category: .globalShopping),
    PresetExtension(name: "Hudson's Bay",    urlString: "https://www.thebay.com",                iconName: "building.columns",           category: .globalShopping),
    PresetExtension(name: "Indigo Books",    urlString: "https://www.indigo.ca",                 iconName: "book.fill",                  category: .globalShopping),
    PresetExtension(name: "Newegg",          urlString: "https://www.newegg.com",                iconName: "cpu",                        category: .globalShopping),
    PresetExtension(name: "Rakuten",         urlString: "https://www.rakuten.com",               iconName: "r.circle",                   category: .globalShopping),
    PresetExtension(name: "Poshmark",        urlString: "https://poshmark.com",                  iconName: "tag.fill",                   category: .globalShopping),
    PresetExtension(name: "Depop",           urlString: "https://www.depop.com",                 iconName: "arrow.2.circlepath",         category: .globalShopping),
    PresetExtension(name: "Taobao",          urlString: "https://m.taobao.com",                  iconName: "cart.badge.plus",            category: .globalShopping),
    PresetExtension(name: "Zalando",         urlString: "https://www.zalando.com",               iconName: "z.circle",                   category: .globalShopping),
    PresetExtension(name: "IKEA",            urlString: "https://www.ikea.com",                  iconName: "bed.double.fill",            category: .globalShopping),

    // MARK: - 7. News & Media (26)
    PresetExtension(name: "BBC News",        urlString: "https://www.bbc.com/news",              iconName: "newspaper",                  category: .newsAndMedia),
    PresetExtension(name: "CBC News",        urlString: "https://www.cbc.ca/news",               iconName: "globe.americas.fill",        category: .newsAndMedia),
    PresetExtension(name: "The Globe & Mail", urlString: "https://www.theglobeandmail.com",      iconName: "newspaper.fill",             category: .newsAndMedia),
    PresetExtension(name: "National Post",   urlString: "https://nationalpost.com",              iconName: "doc.richtext.fill",          category: .newsAndMedia),
    PresetExtension(name: "Toronto Star",    urlString: "https://www.thestar.com",               iconName: "star.fill",                  category: .newsAndMedia),
    PresetExtension(name: "Reuters",         urlString: "https://www.reuters.com",               iconName: "globe.americas",             category: .newsAndMedia),
    PresetExtension(name: "CNN",             urlString: "https://edition.cnn.com",               iconName: "play.tv",                    category: .newsAndMedia),
    PresetExtension(name: "TechCrunch",      urlString: "https://techcrunch.com",                iconName: "bolt",                       category: .newsAndMedia),
    PresetExtension(name: "The Verge",       urlString: "https://www.theverge.com",              iconName: "laptopcomputer",             category: .newsAndMedia),
    PresetExtension(name: "Bloomberg",       urlString: "https://www.bloomberg.com",             iconName: "chart.line.uptrend.xyaxis",  category: .newsAndMedia),
    PresetExtension(name: "Hacker News",     urlString: "https://news.ycombinator.com",          iconName: "square.stack.3d.up",         category: .newsAndMedia),
    PresetExtension(name: "Wikipedia",       urlString: "https://en.m.wikipedia.org",            iconName: "book",                       category: .newsAndMedia),
    PresetExtension(name: "The Guardian",    urlString: "https://www.theguardian.com",           iconName: "shield",                     category: .newsAndMedia),
    PresetExtension(name: "NYT",             urlString: "https://www.nytimes.com",               iconName: "t.square",                   category: .newsAndMedia),
    PresetExtension(name: "Ars Technica",    urlString: "https://arstechnica.com",               iconName: "flask",                      category: .newsAndMedia),
    PresetExtension(name: "Wired",           urlString: "https://www.wired.com",                 iconName: "w.circle",                   category: .newsAndMedia),
    PresetExtension(name: "AP News",         urlString: "https://apnews.com",                    iconName: "dot.radiowaves.left.and.right", category: .newsAndMedia),
    PresetExtension(name: "Al Jazeera",      urlString: "https://www.aljazeera.com",             iconName: "globe",                      category: .newsAndMedia),
    PresetExtension(name: "Der Spiegel",     urlString: "https://www.spiegel.de",                iconName: "globe.europe.africa",        category: .newsAndMedia),
    PresetExtension(name: "Le Monde",        urlString: "https://www.lemonde.fr",                iconName: "l.circle",                   category: .newsAndMedia),
    PresetExtension(name: "NHK World",       urlString: "https://www3.nhk.or.jp/nhkworld",       iconName: "globe.asia.australia",       category: .newsAndMedia),
    PresetExtension(name: "CTV News",        urlString: "https://www.ctvnews.ca",                iconName: "play.rectangle.fill",        category: .newsAndMedia),
    PresetExtension(name: "Global News",     urlString: "https://globalnews.ca",                 iconName: "globe.central.south.asia",   category: .newsAndMedia),
    PresetExtension(name: "The Atlantic",    urlString: "https://www.theatlantic.com",           iconName: "ocean",                      category: .newsAndMedia),
    PresetExtension(name: "Flipboard",       urlString: "https://flipboard.com",                 iconName: "square.stack",               category: .newsAndMedia),
    PresetExtension(name: "Pocket",          urlString: "https://getpocket.com",                 iconName: "bookmark",                   category: .newsAndMedia),

    // MARK: - 8. Streaming & Audio (26)
    PresetExtension(name: "YouTube",         urlString: "https://m.youtube.com",                 iconName: "play.rectangle",             category: .streamingAndAudio),
    PresetExtension(name: "Twitch",          urlString: "https://m.twitch.tv",                   iconName: "gamecontroller",             category: .streamingAndAudio),
    PresetExtension(name: "Spotify",         urlString: "https://open.spotify.com",              iconName: "music.note",                 category: .streamingAndAudio),
    PresetExtension(name: "SoundCloud",      urlString: "https://m.soundcloud.com",              iconName: "waveform",                   category: .streamingAndAudio),
    PresetExtension(name: "Apple Music",     urlString: "https://music.apple.com",               iconName: "music.quarternote.3",        category: .streamingAndAudio),
    PresetExtension(name: "Netflix",         urlString: "https://www.netflix.com",               iconName: "film",                       category: .streamingAndAudio),
    PresetExtension(name: "Disney+",         urlString: "https://www.disneyplus.com",            iconName: "sparkles.tv",                category: .streamingAndAudio),
    PresetExtension(name: "HBO Max",         urlString: "https://www.max.com",                   iconName: "tv.fill",                    category: .streamingAndAudio),
    PresetExtension(name: "Hulu",            urlString: "https://www.hulu.com",                  iconName: "play.circle.fill",           category: .streamingAndAudio),
    PresetExtension(name: "Amazon Prime",    urlString: "https://www.amazon.com/gp/video",       iconName: "play.square.stack",          category: .streamingAndAudio),
    PresetExtension(name: "Crave Canada",    urlString: "https://www.crave.ca",                  iconName: "c.circle.fill",              category: .streamingAndAudio),
    PresetExtension(name: "CBC Gem",         urlString: "https://gem.cbc.ca",                    iconName: "play.tv.fill",               category: .streamingAndAudio),
    PresetExtension(name: "Apple TV+",       urlString: "https://tv.apple.com",                  iconName: "appletv",                    category: .streamingAndAudio),
    PresetExtension(name: "Peacock",         urlString: "https://www.peacocktv.com",             iconName: "bird",                       category: .streamingAndAudio),
    PresetExtension(name: "Paramount+",      urlString: "https://www.paramountplus.com",         iconName: "mountain.2",                 category: .streamingAndAudio),
    PresetExtension(name: "TED Talks",       urlString: "https://www.ted.com",                   iconName: "lightbulb",                  category: .streamingAndAudio),
    PresetExtension(name: "Tidal",           urlString: "https://tidal.com",                     iconName: "water.waves",                category: .streamingAndAudio),
    PresetExtension(name: "Deezer",          urlString: "https://www.deezer.com",                iconName: "music.note.list",            category: .streamingAndAudio),
    PresetExtension(name: "YouTube Music",   urlString: "https://music.youtube.com",             iconName: "music.mic",                  category: .streamingAndAudio),
    PresetExtension(name: "Bandcamp",        urlString: "https://bandcamp.com",                  iconName: "b.circle",                   category: .streamingAndAudio),
    PresetExtension(name: "Crunchyroll",     urlString: "https://www.crunchyroll.com",           iconName: "theatermasks",               category: .streamingAndAudio),
    PresetExtension(name: "Plex Web",        urlString: "https://app.plex.tv",                   iconName: "server.rack",                category: .streamingAndAudio),
    PresetExtension(name: "IMDb",            urlString: "https://m.imdb.com",                    iconName: "movieclapper",               category: .streamingAndAudio),
    PresetExtension(name: "Rotten Tomatoes", urlString: "https://www.rottentomatoes.com",        iconName: "tomato",                     category: .streamingAndAudio),
    PresetExtension(name: "Letterboxd",      urlString: "https://letterboxd.com",                iconName: "film.stack",                 category: .streamingAndAudio),
    PresetExtension(name: "Mixcloud",        urlString: "https://www.mixcloud.com",              iconName: "slider.horizontal.3",        category: .streamingAndAudio),

    // MARK: - 9. Food & Delivery (26)
    PresetExtension(name: "SkipTheDishes",   urlString: "https://www.skipthedishes.com",         iconName: "fork.knife",                 category: .foodAndDelivery),
    PresetExtension(name: "Tim Hortons",     urlString: "https://www.timhortons.ca",             iconName: "cup.and.saucer.fill",        category: .foodAndDelivery),
    PresetExtension(name: "Uber Eats",       urlString: "https://www.ubereats.com",              iconName: "car.fill",                   category: .foodAndDelivery),
    PresetExtension(name: "DoorDash",        urlString: "https://www.doordash.com",              iconName: "bag.fill",                   category: .foodAndDelivery),
    PresetExtension(name: "Instacart",       urlString: "https://www.instacart.com",             iconName: "basket.fill",                category: .foodAndDelivery),
    PresetExtension(name: "Grubhub",         urlString: "https://www.grubhub.com",               iconName: "takeoutbag.and.cup.and.straw", category: .foodAndDelivery),
    PresetExtension(name: "Yelp",            urlString: "https://m.yelp.com",                    iconName: "star.fill",                  category: .foodAndDelivery),
    PresetExtension(name: "Starbucks",       urlString: "https://www.starbucks.com",             iconName: "cup.and.saucer",             category: .foodAndDelivery),
    PresetExtension(name: "McDonald's",      urlString: "https://www.mcdonalds.com",             iconName: "m.square.fill",              category: .foodAndDelivery),
    PresetExtension(name: "Domino's",        urlString: "https://www.dominos.com",               iconName: "circle.grid.2x2",            category: .foodAndDelivery),
    PresetExtension(name: "Pizza Hut",       urlString: "https://www.pizzahut.com",              iconName: "house.fill",                 category: .foodAndDelivery),
    PresetExtension(name: "OpenTable",       urlString: "https://www.opentable.com",             iconName: "table.furniture",            category: .foodAndDelivery),
    PresetExtension(name: "Resy",            urlString: "https://resy.com",                      iconName: "calendar.badge.clock",       category: .foodAndDelivery),
    PresetExtension(name: "Deliveroo",       urlString: "https://deliveroo.com",                 iconName: "bicycle",                    category: .foodAndDelivery),
    PresetExtension(name: "Just Eat",        urlString: "https://www.just-eat.com",              iconName: "flame",                      category: .foodAndDelivery),
    PresetExtension(name: "Chipotle",        urlString: "https://www.chipotle.com",              iconName: "leaf.fill",                  category: .foodAndDelivery),
    PresetExtension(name: "Subway",          urlString: "https://order.subway.com",              iconName: "takeoutbag.and.cup.and.straw.fill", category: .foodAndDelivery),
    PresetExtension(name: "Wendy's",         urlString: "https://order.wendys.com",              iconName: "w.square.fill",              category: .foodAndDelivery),
    PresetExtension(name: "A&W Canada",      urlString: "https://web.aw.ca",                     iconName: "mug.fill",                   category: .foodAndDelivery),
    PresetExtension(name: "Metro Canada",    urlString: "https://www.metro.ca",                  iconName: "cart.fill",                  category: .foodAndDelivery),
    PresetExtension(name: "Loblaws",         urlString: "https://www.loblaws.ca",                iconName: "basket",                     category: .foodAndDelivery),
    PresetExtension(name: "Voila Sobeys",    urlString: "https://voila.ca",                      iconName: "carrot.fill",                category: .foodAndDelivery),
    PresetExtension(name: "HelloFresh",      urlString: "https://www.hellofresh.ca",             iconName: "leaf.circle",                category: .foodAndDelivery),
    PresetExtension(name: "Goodfood",        urlString: "https://www.makegoodfood.ca",           iconName: "heart.text.square",          category: .foodAndDelivery),
    PresetExtension(name: "Zomato",          urlString: "https://www.zomato.com",                iconName: "z.circle.fill",              category: .foodAndDelivery),
    PresetExtension(name: "Swiggy",          urlString: "https://www.swiggy.com",                iconName: "scooter",                    category: .foodAndDelivery),

    // MARK: - 10. Travel & Maps (27)
    PresetExtension(name: "Google Maps",     urlString: "https://maps.google.com",               iconName: "map",                        category: .travelAndMaps),
    PresetExtension(name: "Airbnb",          urlString: "https://www.airbnb.com",                iconName: "house",                      category: .travelAndMaps),
    PresetExtension(name: "Booking.com",     urlString: "https://www.booking.com",               iconName: "bed.double",                 category: .travelAndMaps),
    PresetExtension(name: "Tripadvisor",     urlString: "https://www.tripadvisor.com",           iconName: "suitcase",                   category: .travelAndMaps),
    PresetExtension(name: "Flightradar24",   urlString: "https://www.flightradar24.com",         iconName: "airplane",                   category: .travelAndMaps),
    PresetExtension(name: "Uber",            urlString: "https://m.uber.com",                    iconName: "car",                        category: .travelAndMaps),
    PresetExtension(name: "Google Flights",  urlString: "https://www.google.com/travel/flights", iconName: "airplane.circle",            category: .travelAndMaps),
    PresetExtension(name: "Air Canada",      urlString: "https://www.aircanada.com",             iconName: "leaf.fill",                  category: .travelAndMaps),
    PresetExtension(name: "WestJet",         urlString: "https://www.westjet.com",               iconName: "airplane.departure",         category: .travelAndMaps),
    PresetExtension(name: "VIA Rail",        urlString: "https://www.viarail.ca",                iconName: "train.side.front.car",       category: .travelAndMaps),
    PresetExtension(name: "Expedia",         urlString: "https://www.expedia.com",               iconName: "globe.americas.fill",        category: .travelAndMaps),
    PresetExtension(name: "Kayak",           urlString: "https://www.kayak.com",                 iconName: "arrow.left.arrow.right",     category: .travelAndMaps),
    PresetExtension(name: "Skyscanner",      urlString: "https://www.skyscanner.com",            iconName: "binoculars",                 category: .travelAndMaps),
    PresetExtension(name: "Hotels.com",      urlString: "https://www.hotels.com",                iconName: "building",                   category: .travelAndMaps),
    PresetExtension(name: "Hostelworld",     urlString: "https://www.hostelworld.com",           iconName: "backpack",                   category: .travelAndMaps),
    PresetExtension(name: "Rome2rio",        urlString: "https://www.rome2rio.com",              iconName: "figure.walk.motion",         category: .travelAndMaps),
    PresetExtension(name: "Lyft",            urlString: "https://www.lyft.com",                  iconName: "car.2",                      category: .travelAndMaps),
    PresetExtension(name: "Waze",            urlString: "https://www.waze.com",                  iconName: "location.fill",              category: .travelAndMaps),
    PresetExtension(name: "TripIt",          urlString: "https://www.tripit.com",                iconName: "list.clipboard",             category: .travelAndMaps),
    PresetExtension(name: "Viator",          urlString: "https://www.viator.com",                iconName: "ticket",                     category: .travelAndMaps),
    PresetExtension(name: "Rentalcars",      urlString: "https://www.rentalcars.com",            iconName: "car.side",                   category: .travelAndMaps),
    PresetExtension(name: "Amtrak",          urlString: "https://www.amtrak.com",                iconName: "tram.fill",                  category: .travelAndMaps),
    PresetExtension(name: "FlightAware",     urlString: "https://www.flightaware.com",           iconName: "dot.radiowaves.right",       category: .travelAndMaps),
    PresetExtension(name: "GasBuddy",        urlString: "https://www.gasbuddy.com",              iconName: "fuelpump.fill",              category: .travelAndMaps),
    PresetExtension(name: "Transit App",     urlString: "https://transitapp.com",                iconName: "bus.fill",                   category: .travelAndMaps),
    PresetExtension(name: "Citymapper",      urlString: "https://citymapper.com",                iconName: "map.fill",                   category: .travelAndMaps),
    PresetExtension(name: "AllTrails Maps",  urlString: "https://www.alltrails.com/explore",     iconName: "mountain.2.fill",            category: .travelAndMaps),

    // MARK: - 11. Productivity & Workspace (29)
    PresetExtension(name: "Notion",          urlString: "https://www.notion.so",                 iconName: "note.text",                  category: .productivityAndNotes),
    PresetExtension(name: "Google Keep",     urlString: "https://keep.google.com",               iconName: "checkmark.square",           category: .productivityAndNotes),
    PresetExtension(name: "Trello",          urlString: "https://trello.com",                    iconName: "square.grid.2x2",            category: .productivityAndNotes),
    PresetExtension(name: "Todoist",         urlString: "https://todoist.com",                   iconName: "list.bullet.indent",         category: .productivityAndNotes),
    PresetExtension(name: "Asana",           urlString: "https://app.asana.com",                 iconName: "checkmark.circle",           category: .productivityAndNotes),
    PresetExtension(name: "Canva",           urlString: "https://www.canva.com",                 iconName: "paintpalette",               category: .productivityAndNotes),
    PresetExtension(name: "Google Docs",     urlString: "https://docs.google.com",               iconName: "doc.text",                   category: .productivityAndNotes),
    PresetExtension(name: "Google Sheets",   urlString: "https://sheets.google.com",             iconName: "tablecells",                 category: .productivityAndNotes),
    PresetExtension(name: "Google Drive",    urlString: "https://drive.google.com",              iconName: "internaldrive",              category: .productivityAndNotes),
    PresetExtension(name: "Dropbox",         urlString: "https://www.dropbox.com",               iconName: "archivebox",                 category: .productivityAndNotes),
    PresetExtension(name: "Airtable",        urlString: "https://airtable.com",                  iconName: "tablecells.fill",            category: .productivityAndNotes),
    PresetExtension(name: "Monday.com",      urlString: "https://monday.com",                    iconName: "m.square",                   category: .productivityAndNotes),
    PresetExtension(name: "Jira",            urlString: "https://id.atlassian.com",              iconName: "j.circle",                   category: .productivityAndNotes),
    PresetExtension(name: "Confluence",      urlString: "https://www.atlassian.com/software/confluence", iconName: "c.circle", category: .productivityAndNotes),
    PresetExtension(name: "Figma",           urlString: "https://www.figma.com",                 iconName: "pencil.and.ruler",           category: .productivityAndNotes),
    PresetExtension(name: "Miro",            urlString: "https://miro.com/app",                  iconName: "rectangle.on.rectangle",     category: .productivityAndNotes),
    PresetExtension(name: "Linear",          urlString: "https://linear.app",                    iconName: "arrow.right.circle",         category: .productivityAndNotes),
    PresetExtension(name: "Loom",            urlString: "https://www.loom.com",                  iconName: "video.circle",               category: .productivityAndNotes),
    PresetExtension(name: "Calendly",        urlString: "https://calendly.com",                  iconName: "calendar",                   category: .productivityAndNotes),
    PresetExtension(name: "Obsidian Sync",   urlString: "https://obsidian.md",                   iconName: "diamond",                    category: .productivityAndNotes),
    PresetExtension(name: "Coda",            urlString: "https://coda.io",                       iconName: "doc.richtext",               category: .productivityAndNotes),
    PresetExtension(name: "ClickUp",         urlString: "https://app.clickup.com",               iconName: "arrow.up.circle.fill",       category: .productivityAndNotes),
    PresetExtension(name: "Basecamp",        urlString: "https://launchpad.37signals.com",       iconName: "flame.fill",                 category: .productivityAndNotes),
    PresetExtension(name: "Grammarly",       urlString: "https://app.grammarly.com",             iconName: "text.badge.checkmark",       category: .productivityAndNotes),
    PresetExtension(name: "Evernote Web",    urlString: "https://www.evernote.com/Login.action", iconName: "note",                       category: .productivityAndNotes),
    PresetExtension(name: "Zoom Web",        urlString: "https://zoom.us/signin",                iconName: "video.fill",                 category: .productivityAndNotes),
    PresetExtension(name: "Microsoft 365",   urlString: "https://www.office.com",                iconName: "square.grid.3x3.fill",       category: .productivityAndNotes),
    PresetExtension(name: "Fastmail",        urlString: "https://www.fastmail.com",              iconName: "envelope.fill",              category: .productivityAndNotes),
    PresetExtension(name: "Proton Mail",     urlString: "https://mail.proton.me",                iconName: "lock.fill",                  category: .productivityAndNotes),
]
