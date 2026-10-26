import Foundation

public enum DeviceType: String, CaseIterable, Identifiable {
    case phones      = "Phones"
    case tablets     = "Tablets"
    case desktop     = "Desktop"
    case gaming      = "Gaming Consoles"
    case tv          = "Smart TVs"
    case wearables   = "Wearables & Novelty"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .phones:    return "iphone"
        case .tablets:   return "ipad"
        case .desktop:   return "desktopcomputer"
        case .gaming:    return "gamecontroller.fill"
        case .tv:        return "tv.fill"
        case .wearables: return "applewatch"
        }
    }
}

public enum DevicePreset: String, CaseIterable, Identifiable, Codable {

    // ── Common Phones ──────────────────────────────────────────────────────
    case iPhoneMini         = "iPhone 13 mini"
    case iPhoneSE           = "iPhone SE (2022)"
    case iPhone16Pro        = "iPhone 16 Pro"
    case iPhone16ProMax     = "iPhone 16 Pro Max"
    case pixel9             = "Google Pixel 9"
    case galaxyS24          = "Samsung Galaxy S24"

    // ── Obscure / Spoofing Phones ──────────────────────────────────────────
    case nokiaLumia         = "Nokia Lumia 1520"        // WP8 browser — very rare
    case blackBerryPassport = "BlackBerry Passport"     // BB10 UA — bypasses many paywalls
    case samsungGalaxyFold  = "Samsung Galaxy Z Fold 5" // Unusual inner-display UA
    case huaweiP50Pro       = "Huawei P50 Pro"          // No Google services UA
    case xiaomiMi13         = "Xiaomi 13 Pro"           // MIUI browser UA
    case oppoFindX6         = "OPPO Find X6 Pro"        // ColorOS UA
    case vivoX100           = "Vivo X100 Pro"           // OriginOS UA
    case tecnoSpark         = "Tecno Spark 20"          // Budget African market UA
    case infinixNote        = "Infinix Note 40 Pro"     // Budget Asian market UA
    case nokiaG60           = "Nokia G60 5G"            // HMD basic Android UA
    case motorolaG84        = "Motorola Moto G84"       // Near-stock Android UA
    case sonyXperia1        = "Sony Xperia 1 VI"        // 21:9 unusual viewport UA

    // ── Wearables & Novelty ───────────────────────────────────────────────
    case appleWatch         = "Apple Watch (webOS)"     // Watch UA — rare access
    case palmCompact        = "Palm Phone (Ultra Compact)" // 300x480 novelty UA
    case baiduBox           = "Baidu Smart Speaker"     // IoT UA — usually unrestricted
    case oculus2            = "Meta Quest 2 Browser"    // VR headset UA

    // ── Tablets & E-Readers ───────────────────────────────────────────────
    case amazonFireHD       = "Amazon Fire HD 8"        // Silk browser UA
    case kindlePaperwhite   = "Kindle Paperwhite"       // Experimental browser
    case iPadMini           = "iPad Mini (6th gen)"
    case iPadPro            = "iPad Pro 13-inch"
    case chromebook         = "Chromebook Pixel"        // ChromeOS tablet UA

    // ── Gaming Consoles ───────────────────────────────────────────────────
    case playStation5       = "PlayStation 5 Browser"   // PS5 UA — bypasses many walls
    case nintendoSwitch     = "Nintendo Switch Browser" // Switch UA — very permissive
    case wiiU               = "Wii U Internet Browser"  // Ancient Wii U UA
    case xboxSeriesX        = "Xbox Series X Edge"      // Xbox browser UA

    // ── Smart TVs ─────────────────────────────────────────────────────────
    case googleTV           = "Google TV (4K)"          // TV browser UA
    case samsungSmartTV     = "Samsung Smart TV (Tizen)"// Tizen browser UA
    case lgWebOS            = "LG WebOS TV"             // WebOS UA — often bypasses geo

    // ── Desktop ───────────────────────────────────────────────────────────
    case desktopMac         = "Desktop Safari (Mac)"
    case desktopChrome      = "Desktop Chrome (Windows)"

    // ─────────────────────────────────────────────────────────────────────
    public static let defaultPreset: DevicePreset = .iPhoneMini
    public var id: String { rawValue }

    public var deviceType: DeviceType {
        switch self {
        case .iPhoneMini, .iPhoneSE, .iPhone16Pro, .iPhone16ProMax, .pixel9, .galaxyS24,
             .nokiaLumia, .blackBerryPassport, .samsungGalaxyFold, .huaweiP50Pro,
             .xiaomiMi13, .oppoFindX6, .vivoX100, .tecnoSpark, .infinixNote,
             .nokiaG60, .motorolaG84, .sonyXperia1:
            return .phones
        case .appleWatch, .palmCompact, .baiduBox, .oculus2:
            return .wearables
        case .amazonFireHD, .kindlePaperwhite, .iPadMini, .iPadPro, .chromebook:
            return .tablets
        case .playStation5, .nintendoSwitch, .wiiU, .xboxSeriesX:
            return .gaming
        case .googleTV, .samsungSmartTV, .lgWebOS:
            return .tv
        case .desktopMac, .desktopChrome:
            return .desktop
        }
    }

    public var dimensions: CGSize {
        switch self {
        case .palmCompact:        return CGSize(width: 300, height: 480)
        case .iPhoneMini:         return CGSize(width: 360, height: 640)
        case .iPhoneSE:           return CGSize(width: 375, height: 667)
        case .iPhone16Pro:        return CGSize(width: 393, height: 852)
        case .iPhone16ProMax:     return CGSize(width: 430, height: 932)
        case .pixel9:             return CGSize(width: 412, height: 915)
        case .galaxyS24:          return CGSize(width: 384, height: 854)
        case .nokiaLumia:         return CGSize(width: 360, height: 640)
        case .blackBerryPassport: return CGSize(width: 453, height: 453) // square!
        case .amazonFireHD:       return CGSize(width: 800, height: 1280)
        case .kindlePaperwhite:   return CGSize(width: 758, height: 1024)
        case .samsungGalaxyFold:  return CGSize(width: 904, height: 832)
        case .huaweiP50Pro:       return CGSize(width: 392, height: 873)
        case .xiaomiMi13:         return CGSize(width: 393, height: 851)
        case .oppoFindX6:         return CGSize(width: 412, height: 919)
        case .vivoX100:           return CGSize(width: 393, height: 852)
        case .tecnoSpark:         return CGSize(width: 360, height: 800)
        case .infinixNote:        return CGSize(width: 390, height: 844)
        case .nokiaG60:           return CGSize(width: 360, height: 780)
        case .motorolaG84:        return CGSize(width: 392, height: 873)
        case .sonyXperia1:        return CGSize(width: 360, height: 840) // 21:9
        case .googleTV:           return CGSize(width: 1920, height: 1080)
        case .samsungSmartTV:     return CGSize(width: 1920, height: 1080)
        case .lgWebOS:            return CGSize(width: 1920, height: 1080)
        case .playStation5:       return CGSize(width: 1920, height: 1080)
        case .nintendoSwitch:     return CGSize(width: 1280, height: 720)
        case .wiiU:               return CGSize(width: 854, height: 480)
        case .xboxSeriesX:        return CGSize(width: 1920, height: 1080)
        case .oculus2:            return CGSize(width: 1832, height: 1920)
        case .appleWatch:         return CGSize(width: 198, height: 242)
        case .baiduBox:           return CGSize(width: 800, height: 480)
        case .chromebook:         return CGSize(width: 1280, height: 850)
        case .iPadMini:           return CGSize(width: 744, height: 1133)
        case .iPadPro:            return CGSize(width: 1024, height: 1366)
        case .desktopMac:         return CGSize(width: 1280, height: 800)
        case .desktopChrome:      return CGSize(width: 1366, height: 768)
        }
    }

    /// Screen area in pixels, used for ascending sorting
    public var screenArea: Double {
        Double(dimensions.width * dimensions.height)
    }

    public var resolutionString: String {
        "\(Int(dimensions.width)) × \(Int(dimensions.height))"
    }

    /// Returns all devices belonging to a specific type, sorted by screen size
    public static func devices(for type: DeviceType) -> [DevicePreset] {
        allCases
            .filter { $0.deviceType == type }
            .sorted { $0.screenArea < $1.screenArea }
    }

    public var iconName: String {
        switch self {
        case .palmCompact:        return "hand.raised.app"
        case .iPhoneMini:         return "iphone"
        case .iPhoneSE:           return "iphone.gen1"
        case .iPhone16Pro:        return "iphone.gen3"
        case .iPhone16ProMax:     return "iphone.rear.camera"
        case .pixel9:             return "phone.fill"
        case .galaxyS24:          return "phone.connection"
        case .nokiaLumia:         return "rectangle.portrait.fill"
        case .blackBerryPassport: return "square.fill"
        case .amazonFireHD:       return "flame.fill"
        case .kindlePaperwhite:   return "book.pages.fill"
        case .samsungGalaxyFold:  return "rectangle.on.rectangle.angled.fill"
        case .huaweiP50Pro:       return "camera.aperture"
        case .xiaomiMi13:         return "star.circle.fill"
        case .oppoFindX6:         return "viewfinder.circle.fill"
        case .vivoX100:           return "v.circle.fill"
        case .tecnoSpark:         return "bolt.circle.fill"
        case .infinixNote:        return "infinity.circle"
        case .nokiaG60:           return "n.circle.fill"
        case .motorolaG84:        return "m.circle.fill"
        case .sonyXperia1:        return "s.circle.fill"
        case .googleTV:           return "tv.fill"
        case .samsungSmartTV:     return "play.tv.fill"
        case .lgWebOS:            return "tv.circle.fill"
        case .playStation5:       return "gamecontroller.fill"
        case .nintendoSwitch:     return "gamecontroller"
        case .wiiU:               return "rectangle.on.rectangle.fill"
        case .xboxSeriesX:        return "xmark.circle.fill"
        case .oculus2:            return "visionpro"
        case .appleWatch:         return "applewatch"
        case .baiduBox:           return "speaker.wave.2.fill"
        case .chromebook:         return "macbook"
        case .iPadMini:           return "ipad"
        case .iPadPro:            return "ipad.landscape"
        case .desktopMac:         return "desktopcomputer"
        case .desktopChrome:      return "display"
        }
    }

    public var userAgent: String {
        switch self {
        case .palmCompact, .iPhoneMini:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        case .iPhoneSE:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        case .iPhone16Pro, .iPhone16ProMax:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1"
        case .pixel9:
            return "Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36"
        case .galaxyS24:
            return "Mozilla/5.0 (Linux; Android 14; SM-S921B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36 Samsung/SamsungBrowser/24.0"
        case .nokiaLumia:
            return "Mozilla/5.0 (compatible; MSIE 10.0; Windows Phone 8.0; Trident/6.0; IEMobile/10.0; ARM; Touch; NOKIA; Lumia 1520)"
        case .blackBerryPassport:
            return "Mozilla/5.0 (BB10; Touch) AppleWebKit/537.35+ (KHTML, like Gecko) Version/10.3.3.3216 Mobile Safari/537.35+"
        case .amazonFireHD:
            return "Mozilla/5.0 (Linux; Android 9; KFONUWI) AppleWebKit/537.36 (KHTML, like Gecko) Silk/97.4.9 like Chrome/97.0.4692.87 Safari/537.36"
        case .kindlePaperwhite:
            return "Mozilla/5.0 (X11; U; Linux armv7l like Android; en-us) AppleWebKit/531.2+ (KHTML, like Gecko) Version/5.0 Safari/533.2+ Kindle/3.0+"
        case .samsungGalaxyFold:
            return "Mozilla/5.0 (Linux; Android 14; SM-F946B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36 Samsung/SamsungBrowser/24.0"
        case .huaweiP50Pro:
            return "Mozilla/5.0 (Linux; Android 12; HarmonyOS; HUAWEI JAD-AL50; HMSCore 6.13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.88 HuaweiBrowser/12.1.4.302"
        case .xiaomiMi13:
            return "Mozilla/5.0 (Linux; Android 13; 2210132C) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36 XiaoMi/MiuiBrowser/18.6.50"
        case .oppoFindX6:
            return "Mozilla/5.0 (Linux; Android 13; PGEM10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36"
        case .vivoX100:
            return "Mozilla/5.0 (Linux; Android 14; V2324A) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36"
        case .tecnoSpark:
            return "Mozilla/5.0 (Linux; Android 13; TECNO KJ6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36"
        case .infinixNote:
            return "Mozilla/5.0 (Linux; Android 13; Infinix X6853) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
        case .nokiaG60:
            return "Mozilla/5.0 (Linux; Android 12; Nokia G60 5G) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36"
        case .motorolaG84:
            return "Mozilla/5.0 (Linux; Android 13; moto g84 5g) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36"
        case .sonyXperia1:
            return "Mozilla/5.0 (Linux; Android 14; XQ-EC72) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36"
        case .googleTV:
            return "Mozilla/5.0 (Linux; Android 12; Chromecast with Google TV (4K)) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 CrKey/1.56.500000"
        case .samsungSmartTV:
            return "Mozilla/5.0 (SMART-TV; LINUX; Tizen 8.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/8.0 TV Safari/538.1"
        case .lgWebOS:
            return "Mozilla/5.0 (SMART-TV; Linux; Tizen 5.0 TV) AppleWebKit/538.1 (KHTML, like Gecko) SamsungBrowser/2.1 Safari/538.1"
        case .playStation5:
            return "Mozilla/5.0 (PlayStation 5 4.02) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/604.1"
        case .nintendoSwitch:
            return "Mozilla/5.0 (Nintendo Switch; NintendoBrowser) AppleWebKit/601.6 (KHTML, like Gecko) NintendoBrowser/5.1.0.22023 NintendoSwitch/9.2.0"
        case .wiiU:
            return "Mozilla/5.0 (Nintendo WiiU) AppleWebKit/534.52 (KHTML, like Gecko) NX/3.0.4.2.12 NintendoBrowser/4.3.1.11264.US"
        case .xboxSeriesX:
            return "Mozilla/5.0 (Windows NT 10.0; Win64; x64; Xbox; Xbox Series X) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edge/44.18363.8131"
        case .oculus2:
            return "Mozilla/5.0 (Linux; Android 10; Quest 2) AppleWebKit/537.36 (KHTML, like Gecko) OculusBrowser/27.0.0.4.284.504985392 SamsungBrowser/4.3 Chrome/129.0.6668.73 Mobile VR Safari/537.36"
        case .appleWatch:
            return "Mozilla/5.0 (Apple Watch; CPU Watch OS 10_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/10.0 Peregrine/2403.6.1"
        case .baiduBox:
            return "Mozilla/5.0 (Linux; U; Android 8.1.0; zh-CN; WPS-716-KU Build/OPR1.170623.032) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/57.0.2987.108 UWS/3.22.1.220 Mobile Safari/537.36 UCBS/3.22.1.220"
        case .chromebook:
            return "Mozilla/5.0 (X11; CrOS x86_64 15633.69.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36"
        case .iPadMini:
            return "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        case .iPadPro:
            return "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        case .desktopMac:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        case .desktopChrome:
            return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36"
        }
    }
}
