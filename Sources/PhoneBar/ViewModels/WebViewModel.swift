import AppKit
import WebKit

/// One WKWebView session plus its observable navigation state.
@MainActor
final class WebViewModel: NSObject, ObservableObject {
    var config: WebAppConfig
    @Published var webView: WKWebView
    @Published var currentAccountProfile: AccountProfile = .defaultProfile

    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var isPinned = true   // floating above other windows

    @Published var isSpoofingLocation: Bool = false
    @Published var currentLocation: SpoofedLocation = SpoofedLocation.presets[0]

    // Customizable Browsing Behaviours
    @Published var pageZoom: Double = 1.0 {
        didSet { webView.pageZoom = pageZoom }
    }
    @Published var isForceDarkMode: Bool = false {
        didSet { applyDarkMode() }
    }
    @Published var isAudioMuted: Bool = false {
        didSet { applyMute() }
    }
    @Published var isDesktopMode: Bool = false {
        didSet {
            webView.customUserAgent = isDesktopMode ? DevicePreset.desktopMac.userAgent : config.resolvedUserAgent
            webView.reload()
        }
    }
    @Published var autoRefreshInterval: TimeInterval = 0 {
        didSet { setupAutoRefreshTimer() }
    }
    @Published var windowOpacity: Double = 1.0
    @Published var isGhostMode: Bool = false

    private var autoRefreshTimer: Timer?
    private var observers: [NSKeyValueObservation] = []

    init(config: WebAppConfig, spoofingEnabled: Bool = false, spoofedLocation: SpoofedLocation? = nil) {
        self.config = config
        self.isSpoofingLocation = spoofingEnabled
        if let loc = spoofedLocation {
            self.currentLocation = loc
        }

        let wkConfig = WKWebViewConfiguration()
        wkConfig.websiteDataStore = .default()   // persistent: logins survive window close
        wkConfig.defaultWebpagePreferences.allowsContentJavaScript = true

        // Always inject chat Enter key submit handler so pressing Enter sends messages
        let enterScript = WKUserScript(source: Self.enterKeySubmissionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        wkConfig.userContentController.addUserScript(enterScript)

        if spoofingEnabled {
            let loc = spoofedLocation ?? SpoofedLocation.presets[0]
            let script = Self.buildSynchronizedScript(location: loc)
            let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            wkConfig.userContentController.addUserScript(userScript)
        }

        let wv = WKWebView(frame: .zero, configuration: wkConfig)
        wv.customUserAgent = config.resolvedUserAgent
        wv.allowsBackForwardNavigationGestures = true
        self.webView = wv

        super.init()

        AdBlockService.shared.applyWhenReady(to: wv)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAdBlockChange), name: .adBlockStateChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleGlobalDarkModeChange(_:)), name: .globalForceDarkModeChanged, object: nil)

        // Check if global dark mode is currently active
        if UserDefaults.standard.bool(forKey: "PhoneBar.globalForceDarkMode") {
            self.isForceDarkMode = true
        }

        // Set initial window opacity from user preference
        if let defaultOpacity = UserDefaults.standard.object(forKey: "PhoneBar.globalWindowOpacity") as? Double {
            self.windowOpacity = defaultOpacity
        }

        NotificationCenter.default.addObserver(self, selector: #selector(handleAppearanceSettingsChanged), name: .appearanceSettingsChanged, object: nil)

        wv.navigationDelegate = self
        wv.uiDelegate = self
        observeState()
        goHome()
    }

    @objc private func handleAdBlockChange() {
        AdBlockService.shared.apply(to: webView)
        webView.reload()
    }

    @objc private func handleGlobalDarkModeChange(_ notification: Notification) {
        if let enabled = notification.userInfo?["enabled"] as? Bool {
            self.isForceDarkMode = enabled
        }
    }

    @objc private func handleAppearanceSettingsChanged() {
        if let defaultOpacity = UserDefaults.standard.object(forKey: "PhoneBar.globalWindowOpacity") as? Double {
            self.windowOpacity = defaultOpacity
        }
    }

    // MARK: - Actions

    func setLocationSpoofing(enabled: Bool, location: SpoofedLocation) {
        self.isSpoofingLocation = enabled
        self.currentLocation = location
        webView.configuration.userContentController.removeAllUserScripts()
        let enterScript = WKUserScript(source: Self.enterKeySubmissionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(enterScript)
        if enabled {
            let script = Self.buildSynchronizedScript(location: location)
            let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            webView.configuration.userContentController.addUserScript(userScript)
        }
        webView.reload()
    }

    /// JavaScript to intercept Enter (without Shift) in chat apps like Gemini, Claude, ChatGPT
    /// and trigger submission instead of newline.
    static let enterKeySubmissionScript = """
    (function() {
        if (window.__phonebar_enter_listener_installed) return;
        window.__phonebar_enter_listener_installed = true;

        function findSendButton(element) {
            // Check inside closest form or parent container
            const container = element.closest('form') || element.closest('[class*="chat"], [class*="input"], [class*="prompt"], main, body') || document;
            
            // Common selectors for Gemini, ChatGPT, Claude, and general AI / chat web apps
            const selectors = [
                'button[aria-label*="Send" i]',
                'button[aria-label*="Submit" i]',
                'button[aria-label*="send message" i]',
                'button[data-testid*="send-button" i]',
                'button[data-testid*="send" i]',
                'button.send-button',
                '.send-button-container button',
                'button.mat-mdc-icon-button[aria-label*="Send" i]',
                'button.send-button-component',
                'button[type="submit"]',
                'button.submit-button',
                'button[title*="Send" i]'
            ];

            for (const sel of selectors) {
                const btn = container.querySelector(sel) || document.querySelector(sel);
                if (btn && !btn.disabled && btn.offsetParent !== null) {
                    return btn;
                }
            }

            // Fallback: look for button with SVG / icon representing send
            const buttons = Array.from(document.querySelectorAll('button:not([disabled])'));
            for (const b of buttons) {
                const label = (b.getAttribute('aria-label') || b.innerText || '').toLowerCase();
                if (label.includes('send') || label.includes('submit')) {
                    if (b.offsetParent !== null) return b;
                }
            }
            return null;
        }

        document.addEventListener('keydown', function(e) {
            // Only trigger on Enter without Shift/Ctrl/Alt/Meta
            if (e.key !== 'Enter' || e.shiftKey || e.ctrlKey || e.altKey || e.metaKey || e.isComposing) {
                return;
            }

            const target = e.target;
            if (!target) return;

            // Check if user is typing in a contenteditable, textarea, or text input
            const isEditable = target.isContentEditable || 
                               target.tagName === 'TEXTAREA' || 
                               (target.tagName === 'INPUT' && (target.type === 'text' || target.type === 'search'));

            if (!isEditable) return;

            // Check if there is a send button to trigger
            const sendBtn = findSendButton(target);
            if (sendBtn) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();

                // Dispatch mousedown, mouseup, and click
                sendBtn.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, view: window }));
                sendBtn.dispatchEvent(new MouseEvent('mouseup', { bubbles: true, cancelable: true, view: window }));
                sendBtn.click();
            } else if (target.form) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();
                target.form.requestSubmit ? target.form.requestSubmit() : target.form.submit();
            }
        }, true);
    })();
    """

    private static func buildSynchronizedScript(location: SpoofedLocation) -> String {
        let targetTZ = location.timezone.isEmpty ? "America/New_York" : location.timezone
        let targetLocale = location.locale.isEmpty ? "en-US" : location.locale
        let offsetMinutes = location.timezoneOffsetMinutes
        return """
        (function() {
            // 1. Synchronized HTML5 Geolocation
            const fakePos = {
                coords: {
                    latitude: \(location.latitude),
                    longitude: \(location.longitude),
                    altitude: null,
                    accuracy: 12,
                    altitudeAccuracy: null,
                    heading: null,
                    speed: null
                },
                timestamp: Date.now()
            };
            if (navigator.geolocation) {
                navigator.geolocation.getCurrentPosition = function(s, e, o) { if (s) s(fakePos); };
                navigator.geolocation.watchPosition = function(s, e, o) { if (s) s(fakePos); return 1001; };
                navigator.geolocation.clearWatch = function(id) {};
            }

            // 2. Synchronized TimeZone & Locale
            const targetTZ = "\(targetTZ)";
            const targetLocale = "\(targetLocale)";
            const origDTF = Intl.DateTimeFormat;
            Intl.DateTimeFormat = function(locales, options) {
                options = options || {};
                if (!options.timeZone) options.timeZone = targetTZ;
                return new origDTF(locales || targetLocale, options);
            };
            Intl.DateTimeFormat.prototype = origDTF.prototype;
            Intl.DateTimeFormat.supportedLocalesOf = origDTF.supportedLocalesOf;

            // 3. Synchronized TimeZone Offset
            Date.prototype.getTimezoneOffset = function() {
                return \(offsetMinutes);
            };

            // 4. Synchronized Language
            try {
                Object.defineProperty(navigator, 'language', { get: () => targetLocale, configurable: true });
                Object.defineProperty(navigator, 'languages', { get: () => [targetLocale, "en"], configurable: true });
            } catch(e) {}
        })();
        """
    }

    func updateDevice(_ device: DevicePreset) {
        config.devicePreset = device
        webView.customUserAgent = config.resolvedUserAgent
        webView.reload()
    }

    func goHome() {
        guard let url = config.url else { return }
        webView.load(URLRequest(url: url))
    }

    func switchAccount(to profile: AccountProfile) {
        guard profile != currentAccountProfile else { return }
        self.currentAccountProfile = profile

        let wkConfig = WKWebViewConfiguration()
        if profile.isAnonymous {
            wkConfig.websiteDataStore = .nonPersistent()
        } else if profile.id == "default" {
            wkConfig.websiteDataStore = .default()
        } else {
            if #available(macOS 14.0, *) {
                let uuid = UUID(uuidString: profile.id) ?? UUID()
                wkConfig.websiteDataStore = WKWebsiteDataStore(forIdentifier: uuid)
            } else {
                wkConfig.websiteDataStore = .default()
            }
        }
        wkConfig.defaultWebpagePreferences.allowsContentJavaScript = true

        let enterScript = WKUserScript(source: Self.enterKeySubmissionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        wkConfig.userContentController.addUserScript(enterScript)

        if isSpoofingLocation {
            let script = Self.buildSynchronizedScript(location: currentLocation)
            let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            wkConfig.userContentController.addUserScript(userScript)
        }

        let newWebView = WKWebView(frame: .zero, configuration: wkConfig)
        newWebView.customUserAgent = isDesktopMode ? DevicePreset.desktopMac.userAgent : config.resolvedUserAgent
        newWebView.allowsBackForwardNavigationGestures = true
        newWebView.pageZoom = pageZoom

        // Teardown previous webview
        self.webView.stopLoading()
        self.webView.navigationDelegate = nil
        self.webView.uiDelegate = nil

        self.webView = newWebView
        AdBlockService.shared.apply(to: newWebView)
        newWebView.navigationDelegate = self
        newWebView.uiDelegate = self

        observeState()
        goHome()
    }

    func reloadOrStop() {
        if isLoading { webView.stopLoading() } else { webView.reload() }
    }

    func setupAutoRefreshTimer() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
        guard autoRefreshInterval > 0 else { return }
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.webView.reload()
            }
        }
    }

    func applyDarkMode() {
        let js = """
        (function() {
            let el = document.getElementById('phonebar-dark-mode');
            if (\(isForceDarkMode)) {
                if (!el) {
                    el = document.createElement('style');
                    el.id = 'phonebar-dark-mode';
                    el.innerHTML = `
                        html { filter: invert(90%) hue-rotate(180deg) !important; background: #121212 !important; }
                        img, video, picture, canvas, svg { filter: invert(100%) hue-rotate(180deg) !important; }
                    `;
                    document.head.appendChild(el);
                }
            } else {
                if (el) el.remove();
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func applyMute() {
        let js = """
        (function() {
            document.querySelectorAll('video, audio').forEach(el => el.muted = \(isAudioMuted));
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func clearHostCacheAndReload() {
        guard let host = config.url?.host else { return }
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { [weak self] records in
            let hostRecords = records.filter { $0.displayName.localizedCaseInsensitiveContains(host) }
            store.removeData(ofTypes: types, for: hostRecords) {
                DispatchQueue.main.async {
                    self?.webView.reloadFromOrigin()
                }
            }
        }
    }

    /// Stops media/network activity so a closed window leaves nothing running.
    func teardown() {
        NotificationCenter.default.removeObserver(self, name: .adBlockStateChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .globalForceDarkModeChanged, object: nil)
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
        observers.removeAll()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
    }

    // MARK: - State observation

    private func observeState() {
        let sync: () -> Void = { [weak self] in
            Task { @MainActor in self?.syncState() }
        }
        observers = [
            webView.observe(\.canGoBack) { _, _ in sync() },
            webView.observe(\.canGoForward) { _, _ in sync() },
            webView.observe(\.isLoading) { _, _ in sync() },
            webView.observe(\.estimatedProgress) { _, _ in sync() }
        ]
    }

    private func syncState() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        progress = webView.estimatedProgress
    }

    // MARK: - Helpers

    private func present(_ alert: NSAlert, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = webView.window {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }

    private func showError(_ error: Error) {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
        if ns.domain == "WebKitErrorDomain" && ns.code == 102 { return } // frame load interrupted

        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
             .replacingOccurrences(of: "<", with: "&lt;")
             .replacingOccurrences(of: ">", with: "&gt;")
             .replacingOccurrences(of: "\"", with: "&quot;")
        }
        let failing = (ns.userInfo[NSURLErrorFailingURLStringErrorKey] as? String) ?? config.urlString
        let isProxy = ProxyService.shared.isProxyEnabled
        let proxyButtons = isProxy ? """
        <div style="margin-top:14px;display:flex;gap:8px;justify-content:center;flex-wrap:wrap">
            <a href="phonebar://next-proxy" style="display:inline-block;padding:8px 14px;border-radius:10px;background:#ff9500;color:#fff;text-decoration:none;font-size:13px">⚡️ Rotate Next IP</a>
            <a href="phonebar://bypass-proxy" style="display:inline-block;padding:8px 14px;border-radius:10px;background:#34c759;color:#fff;text-decoration:none;font-size:13px">Direct Mode (Keep Spoofed Geo)</a>
        </div>
        """ : ""
        let html = """
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <style>:root{color-scheme:light dark}
        body{font:16px -apple-system,sans-serif;display:flex;flex-direction:column;align-items:center;
        justify-content:center;height:90vh;margin:0;padding:24px;text-align:center}
        a{display:inline-block;margin-top:12px;padding:10px 22px;border-radius:12px;background:#0a84ff;
        color:#fff;text-decoration:none}</style></head>
        <body><h2>Can’t load page</h2><p>\(esc(ns.localizedDescription))</p>
        <a href="\(esc(failing))">Try Again</a>
        \(proxyButtons)
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: failing))
    }
}

// MARK: - WKNavigationDelegate

extension WebViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.cancel) }
        if let scheme = url.scheme?.lowercased(), scheme == "phonebar" {
            if url.host == "next-proxy" {
                ProxyService.shared.rotateToNextBackupProxy()
                goHome()
            } else if url.host == "bypass-proxy" {
                ProxyService.shared.isProxyEnabled = false
                goHome()
            }
            decisionHandler(.cancel)
            return
        }
        switch url.scheme?.lowercased() {
        case "http", "https", "about", "blob", "data":
            decisionHandler(.allow)
        case "mailto", "tel", "sms":
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        default:
            decisionHandler(.cancel) // app deep links (intent://, etc.) can't be handled here
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showError(error)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if isForceDarkMode { applyDarkMode() }
        if isAudioMuted { applyMute() }
    }
}

// MARK: - WKUIDelegate

extension WebViewModel: WKUIDelegate {
    /// target=_blank / window.open: keep everything inside this phone window.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = frame.request.url?.host ?? config.name
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        present(alert) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = frame.request.url?.host ?? config.name
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        present(alert) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = frame.request.url?.host ?? config.name
        alert.informativeText = prompt
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = defaultText ?? ""
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        present(alert) { completionHandler($0 == .alertFirstButtonReturn ? field.stringValue : nil) }
    }

    /// <input type="file"> support.
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        let finish: (NSApplication.ModalResponse) -> Void = { completionHandler($0 == .OK ? panel.urls : nil) }
        if let window = webView.window {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }

    /// Camera / microphone: defer to the standard macOS permission prompt.
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.prompt)
    }
}
