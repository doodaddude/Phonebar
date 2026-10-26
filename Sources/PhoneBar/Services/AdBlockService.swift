import WebKit
import Combine

/// Compiles and manages a WKContentRuleList-based ad/tracker blocker.
/// Uses the native WebKit Content Blocker API — no proxies, no 3rd-party SDKs.
/// Rules are compiled once and cached; subsequent calls reuse the compiled list.
@MainActor
final class AdBlockService: ObservableObject {

    static let shared = AdBlockService()

    @Published var isEnabled: Bool = UserDefaults.standard.bool(forKey: "PhoneBar.adBlockEnabled") {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "PhoneBar.adBlockEnabled")
            refreshAllWebViews()
        }
    }

    private var compiledList: WKContentRuleList?
    private var compiling = false
    private var pendingWebViews: [WKWebView] = []

    private init() {
        // Pre-compile on launch so it's ready immediately
        Task { await compile() }
    }

    // MARK: - Public API

    /// Apply or remove the block list from a web view according to current state.
    func apply(to webView: WKWebView) {
        if isEnabled, let list = compiledList {
            webView.configuration.userContentController.add(list)
        } else {
            webView.configuration.userContentController.removeAllContentRuleLists()
        }
    }

    /// Compile rules and then apply to a new web view (called from WebViewModel.init).
    func applyWhenReady(to webView: WKWebView) {
        if compiledList != nil {
            apply(to: webView)
        } else {
            pendingWebViews.append(webView)
            if !compiling {
                Task { await compile() }
            }
        }
    }

    // MARK: - Compilation

    private func compile() async {
        guard compiledList == nil, !compiling else { return }
        compiling = true

        let json = Self.blocklistJSON
        do {
            let list = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "com.phonebar.adblock.v3",
                encodedContentRuleList: json
            )
            if let list = list {
                self.compiledList = list
                // Apply to any web views that were waiting
                for wv in pendingWebViews where isEnabled {
                    wv.configuration.userContentController.add(list)
                }
            }
            pendingWebViews.removeAll()
        } catch {
            print("[AdBlock] Rule compilation failed: \(error)")
        }
        compiling = false
    }

    private func refreshAllWebViews() {
        // WindowManager will call apply(to:) on each open webView after toggle
        NotificationCenter.default.post(name: .adBlockStateChanged, object: nil)
    }

    // MARK: - Blocklist Rules (WKContentBlocker JSON format)
    // Covers major ad networks, trackers, telemetry, and cookie consent banners.
    // Pattern: css-display-none for DOM elements, block for network requests.

    private static let blocklistJSON: String = """
    [
      {"trigger":{"url-filter":".*","resource-type":["script","image","style-sheet","raw"],"if-domain":["*doubleclick.net","*googlesyndication.com","*googletagmanager.com","*googletagservices.com","*google-analytics.com","*adnxs.com","*rubiconproject.com","*pubmatic.com","*openx.net","*casalemedia.com","*advertising.com","*taboola.com","*outbrain.com","*moatads.com","*adsrvr.org","*criteo.com","*criteo.net","*quantserve.com","*scorecardresearch.com","*rlcdn.com","*facebook.com","*facebook.net","*connect.facebook.net","*ads.twitter.com","*twitter.com","*ads.linkedin.com","*media.net","*amazon-adsystem.com","*adsystem.amazon.com","*mopub.com","*appnexus.com","*yieldmo.com","*spotxchange.com","*spotx.tv","*lijit.com","*sovrn.com","*gravity.com","*tribalfusion.com","*undertone.com","*adform.net","*smartadserver.com","*sizmek.com","*33across.com","*triplelift.com","*sharethrough.com","*teads.tv","*yimg.com","*indexexchange.com","*openxadexchange.com"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*","resource-type":["script","image","style-sheet","raw"],"if-domain":["*hotjar.com","*fullstory.com","*logrocket.com","*segment.com","*amplitude.com","*mixpanel.com","*heap.io","*mouseflow.com","*clarity.ms","*newrelic.com","*datadog.com","*sentry.io","*bugsnag.com","*raygun.com","*rollbar.com","*tealiumiq.com","*ensighten.com","*branch.io","*adjust.com","*appsflyer.com","*kochava.com","*singular.net"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*","resource-type":["script"],"if-domain":["*cookielaw.org","*onetrust.com","*evidon.com","*trustarc.com","*truste.com","*cookiebot.com","*quantcast.com","*usercentrics.eu","*iubenda.com","*cookiepro.com"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*","resource-type":["script","image","raw"],"if-domain":["*ads.yahoo.com","*advertising.yahoo.com","*gemini.yahoo.com","*adtech.de","*adtechus.com","*snap.licdn.com","*px.ads.linkedin.com","*bat.bing.com","*analytics.twitter.com","*ads-twitter.com","*static.ads-twitter.com","*trc.taboola.com","*cdn.taboola.com","*widgets.outbrain.com","*amplify.outbrain.com","*go.onet.pl","*id5-sync.com","*sync.crwdcntrl.net","*dpm.demdex.net","*cm.everesttech.net"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*googleadservices\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*pagead2\\.googlesyndication\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*(/ads/|/ad/|/adserv|/advert|/adsense/|/doubleclick/|/popup_ad|/prebid\\.js|/gpt\\.js|/ads\\.js|/ad\\.js|/banner\\.js|/tracker\\.js|/tracking\\.js|/analytics\\.js|/pixel\\.gif|/pixel\\.png|/beacon\\.gif|/b\\.gif|/collect|/hit\\.gif)"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.amazon-adsystem\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*cdn\\.ampproject\\.org/v0/amp-ad"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*(/wp-content/plugins/wp-admanager|/wp-content/plugins/wp-ads|adsbygoogle\\.js)"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*","if-domain":["*adcolony.com","*applovin.com","*inmobi.com","*verizonmedia.com","*rhythmone.com","*conversantmedia.com","*tradedesk.com","*thetradedesk.com","*bidswitch.net","*adsafeprotected.com","*doubleverify.com","*integral-ads.com","*forensiq.com","*gumgum.com","*nativo.com","*zedo.com","*valueclick.com","*mathtag.com","*agkn.com"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*","resource-type":["script"],"if-domain":["*chartbeat.com","*chartbeat.net","*parsely.com","*cdp.parsely.com","*rebelmouse.com","*tinypass.com","*piano.io","*cxense.com","*narrative.io"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*fbcdn\\.net/ads"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*facebook\\.com/tr/"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.googletagmanager\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.googletagservices\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.google-analytics\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.doubleclick\\.net"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.googlesyndication\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*scorecardresearch\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.quantserve\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.criteo\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.criteo\\.net"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.taboola\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.outbrain\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.hotjar\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.fullstory\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.segment\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.amplitude\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.mixpanel\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.clarity\\.ms"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.onetrust\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*\\.cookiebot\\.com"},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*","resource-type":["websocket"],"if-domain":["*hotjar.com","*logrocket.com","*fullstory.com"]},"action":{"type":"block"}},
      {"trigger":{"url-filter":".*","resource-type":["image","raw"],"url-filter-is-case-sensitive":false},"action":{"type":"css-display-none","selector":"[id*='ads_'],[id*='_ads'],[class*='ads_'],[class*='_ads'],[id*='google_ads'],[class*='google-ads'],[id^='ad-'],[class^='ad-'],[id$='-ad'],[class$='-ad'],[id*='advert'],[class*='advert'],[id*='banner'],[class*='ad-banner'],[class*='ad-unit'],[class*='adbanner'],#ad_area,.ad-slot,.ad-placeholder,.adsbygoogle,.ads-container,.ad-wrapper,.ad-block-inner,.native-ad,.sponsored-content,[data-ad],[data-ads],[data-ad-slot],[data-ad-unit-id],div[id*='taboola'],div[id*='outbrain'],div[class*='taboola'],div[class*='outbrain'],.cookie-banner,.cookie-consent,.cookie-notice,.gdpr-banner,.cc-window,#cookie-law-info-bar,.onetrust-pc-dark-filter,#onetrust-consent-sdk,.cookiebot-widget"}}
    ]
    """
}

extension Notification.Name {
    static let adBlockStateChanged = Notification.Name("PhoneBar.adBlockStateChanged")
}
