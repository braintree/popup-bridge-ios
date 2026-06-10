import Foundation
import WebKit
import AuthenticationServices

@objcMembers
public class POPPopupBridge: NSObject, WKScriptMessageHandler {

    /// Exposed for testing
    var returnedWithURL: Bool = false
    
    static var analyticsService: AnalyticsServiceable = AnalyticsService()
    
    // MARK: - Private Properties
    
    private let messageHandlerName = "POPPopupBridge"
    private let hostName = "popupbridgev1"
    private let sessionID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    private let webView: WKWebView
    private let application: URLOpener

    private let enablePayPalAppSwitch: Bool
    private let returnURLScheme: String?
    private var webAuthenticationSession: WebAuthenticationSession = WebAuthenticationSession()
    private var returnBlock: ((URL) -> Void)? = nil
    private var payPalLaunchAppReturnObserver: NSObjectProtocol?

    // MARK: - Initializers
        
    /// Initialize a Popup Bridge.
    /// - Parameters:
    ///   - webView: The web view to add a script message handler to. Do not change the web view's configuration or user content controller after initializing Popup Bridge.
    ///   - prefersEphemeralWebBrowserSession: A Boolean that, when true, requests that the browser does not share cookies
    ///   or other browsing data between the authentication session and the user's normal browser session.
    ///   Defaults to `true`.
    ///   - enablePayPalAppSwitch: When true, allows the SDK to launch the native PayPal app for checkout
    ///   instead of opening a browser. Defaults to false for backward compatibility.
    ///   This is specific to the popup bridge flow and is separate from the JS SDK's
    ///   appSwitchWhenAvailable which controls non-webview mobile browser app switch.
    ///
    ///   **Required SceneDelegate integration:** when this flag is `true`, the host app must forward
    ///   incoming URLs from its `SceneDelegate` to PopupBridge via a `NotificationCenter` post,
    ///   otherwise the checkout flow will hang indefinitely after the PayPal app returns.
    ///   In your `SceneDelegate`:
    ///   ```swift
    ///   func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    ///       guard let url = URLContexts.first?.url else { return }
    ///       NotificationCenter.default.post(
    ///           name: PopupBridgeConstants.notificationName,
    ///           object: nil,
    ///           userInfo: ["url": url]
    ///       )
    ///   }
    ///   ```
    ///   - returnURLScheme: The URL scheme registered in the app's `Info.plist` that PopupBridge should
    ///   use as the return URL for the checkout flow. If `nil`, PopupBridge will attempt to read the first
    ///   scheme from `CFBundleURLTypes`. Providing this value explicitly is recommended when the app
    ///   registers multiple URL schemes (e.g. Facebook, Google Sign-In).
    public init(webView: WKWebView, prefersEphemeralWebBrowserSession: Bool = true, enablePayPalAppSwitch: Bool = false, returnURLScheme: String? = nil) {
        self.webView = webView
        self.application = UIApplication.shared
        self.enablePayPalAppSwitch = enablePayPalAppSwitch
        self.returnURLScheme = returnURLScheme

        super.init()

        configureWebView()
        webAuthenticationSession.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession

        returnBlock = { [weak self] url in
            guard let script = self?.constructJavaScriptCompletionResult(returnURL: url) else {
                return
            }

            self?.injectWebView(webView: webView, withJavaScript: script)
            return
        }
    }

    /// Exposed for testing
    convenience init(
        webView: WKWebView,
        webAuthenticationSession: WebAuthenticationSession
    ) {
        self.init(webView: webView)
        self.webAuthenticationSession = webAuthenticationSession
    }

    /// Exposed for testing
    convenience init(
        webView: WKWebView,
        webAuthenticationSession: WebAuthenticationSession,
        enablePayPalAppSwitch: Bool = false,
        application: URLOpener
    ) {
        self.init(webView: webView, enablePayPalAppSwitch: enablePayPalAppSwitch, application: application)
        self.webAuthenticationSession = webAuthenticationSession
    }

    /// Internal designated init that accepts a URLOpener for testing
    init(webView: WKWebView, prefersEphemeralWebBrowserSession: Bool = true, enablePayPalAppSwitch: Bool = false, returnURLScheme: String? = nil, application: URLOpener) {
        self.webView = webView
        self.application = application
        self.enablePayPalAppSwitch = enablePayPalAppSwitch
        self.returnURLScheme = returnURLScheme

        super.init()

        configureWebView()
        webAuthenticationSession.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession

        returnBlock = { [weak self] url in
            guard let script = self?.constructJavaScriptCompletionResult(returnURL: url) else {
                return
            }

            self?.injectWebView(webView: webView, withJavaScript: script)
            return
        }
    }

    deinit {
        if let payPalLaunchAppReturnObserver {
            NotificationCenter.default.removeObserver(payPalLaunchAppReturnObserver)
        }
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
    }
    
    // MARK: - Launch App Return Handling

    /// Starts listening for the return URL notification posted by the host app's SceneDelegate.
    /// Called only after a successful launchApp; removed after handling.
    private func startObservingPayPalLaunchAppReturn() {
        stopObservingPayPalLaunchAppReturn()

        payPalLaunchAppReturnObserver = NotificationCenter.default.addObserver(
            forName: PopupBridgeConstants.notificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else {
                return
            }

            guard let url = notification.userInfo?["url"] as? URL else {
                return
            }

            self.handlePayPalLaunchAppReturn(url: url)
        }
    }

    /// Exposed for testing
    ///
    /// Parses the return URL and injects `window.popupBridge.onComplete()` into the WebView.
    /// The return URL may include fragment-based data:
    ///   merchantapp://popupbridgev1/onApprove#onApprove&PayerID=XXX&token=EC-YYY
    /// Popup Bridge JavaScript is responsible for normalizing `path`, `queryItems`, and `hash`.
    func handlePayPalLaunchAppReturn(url: URL) {
        // Validate before doing anything: the return notification is an open channel, so any code
        // in the host app could post an arbitrary URL to it. Only PopupBridge return URLs may be
        // injected into the WebView. Invalid posts are ignored without consuming the one-shot
        // observer, so a later legitimate return still completes the flow.
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              isValidPayPalReturnURL(urlComponents) else {
            return
        }

        // Valid return: stop observing (one-shot), then forward the result to the WebView.
        stopObservingPayPalLaunchAppReturn()
        injectPayPalReturnResult(makeURLDetailsPayload(from: urlComponents))
    }

    /// Removes the one-shot PayPal launch-app return observer, if registered.
    private func stopObservingPayPalLaunchAppReturn() {
        if let payPalLaunchAppReturnObserver {
            NotificationCenter.default.removeObserver(payPalLaunchAppReturnObserver)
            self.payPalLaunchAppReturnObserver = nil
        }
    }

    /// Flattens a return URL's components into the `URLDetailsPayload` sent to the WebView.
    private func makeURLDetailsPayload(from components: URLComponents) -> URLDetailsPayload {
        let queryItems = components.queryItems?.reduce(into: [String: String]()) { partialResult, queryItem in
            partialResult[queryItem.name] = queryItem.value
        } ?? [:]

        return URLDetailsPayload(
            path: components.path,
            queryItems: queryItems,
            hash: components.fragment
        )
    }

    /// Serializes the payload and injects the completion JS into the WebView, emitting the matching analytics event.
    private func injectPayPalReturnResult(_ payload: URLDetailsPayload) {
        guard let payloadData = try? JSONEncoder().encode(payload),
              let payloadString = String(data: payloadData, encoding: .utf8) else {
            Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.failed, sessionID: sessionID)
            let errorResponse = "new Error(\"Failed to serialize return URL payload as JSON.\")"
            injectWebView(webView: webView, withJavaScript: "window.popupBridge.onComplete(\(errorResponse), null);")
            return
        }

        Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.succeeded, sessionID: sessionID)
        injectWebView(webView: webView, withJavaScript: payPalReturnCompletionScript(payloadString: payloadString))
    }

    /// Builds the JS injected after a successful PayPal app switch return.
    ///
    /// The leading semicolon is a defensive IIFE guard: if the previous JS statement on the page was
    /// left without a semicolon, concatenating a bare `(function(){…})()` would be parsed as a
    /// function-call on that expression and throw. The `;` ensures a clean statement boundary
    /// regardless of surrounding page JS.
    ///
    /// If `onComplete` isn't ready yet (the page's JS may still be loading when the app returns), the
    /// result is stashed on `window.popupBridge.__pendingResult` for the page to pick up.
    private func payPalReturnCompletionScript(payloadString: String) -> String {
        """
        ;(function() {
            if (typeof window.popupBridge !== 'undefined' && typeof window.popupBridge.onComplete === 'function') {
                window.popupBridge.onComplete(null, \(payloadString));
            } else {
                if (!window.popupBridge) { window.popupBridge = {}; }
                window.popupBridge.__pendingResult = \(payloadString);
            }
        })();
        """
    }

    /// Exposed for testing
    ///
    /// Validates that a URL delivered via `PopupBridgeConstants.notificationName` is an actual
    /// PopupBridge return URL, rather than arbitrary data posted to that notification by other
    /// code in the host app. Mirrors the scheme/host check on the `ASWebAuthenticationSession` path.
    /// - Parameter components: the components of the URL received from the return notification.
    /// - Returns: `true` if the URL matches the expected PopupBridge return URL signature.
    func isValidPayPalReturnURL(_ components: URLComponents) -> Bool {
        // Host must be the PopupBridge host (e.g. popupbridgev1).
        guard components.host?.caseInsensitiveCompare(hostName) == .orderedSame else {
            return false
        }

        // Scheme must match the return URL scheme PopupBridge advertised to PayPal. When a scheme
        // can be resolved, enforce it so URLs minted for other schemes are rejected.
        guard let expectedScheme = resolveReturnURLScheme() else {
            return false
        }

        return components.scheme?.caseInsensitiveCompare(expectedScheme) == .orderedSame
    }

    // MARK: - Internal Methods

    /// Exposed for testing
    /// 
    /// Constructs custom JavaScript to be injected into the merchant's WKWebView, based on redirectURL details from the SFSafariViewController pop-up result.
    /// - Parameter url: returnURL from the result of the ASWebAuthenticationSession.
    /// - Returns: JavaScript formatted completion.
    func constructJavaScriptCompletionResult(returnURL: URL) -> String? {
        guard let urlComponents = URLComponents(url: returnURL, resolvingAgainstBaseURL: false),
              urlComponents.scheme?.caseInsensitiveCompare(PopupBridgeConstants.callbackURLScheme) == .orderedSame,
              urlComponents.host?.caseInsensitiveCompare(hostName) == .orderedSame
        else {
            return nil
        }

        let payload = makeURLDetailsPayload(from: urlComponents)

        if let payloadData = try? JSONEncoder().encode(payload),
            let payload = String(data: payloadData, encoding: .utf8) {
            Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.succeeded, sessionID: sessionID)
            return "window.popupBridge.onComplete(null, \(payload));"
        } else {
            let errorMessage = "Failed to parse query items from return URL."
            let errorResponse = "new Error(\"\(errorMessage)\")"
            Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.failed, sessionID: sessionID)
            return "window.popupBridge.onComplete(\(errorResponse), null);"
        }
    }
    
    /// Injects custom JavaScript into the merchant's webpage.
    /// - Parameter scheme: the url scheme provided by the merchant
    private func configureWebView() {
        Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.started, sessionID: sessionID)
        webView.configuration.userContentController.add(
            WebViewScriptHandler(proxy: self),
            name: messageHandlerName
        )
        
        // Even if the PayPal app is physically installed on the device, we intentionally
        // report it as absent to the JavaScript layer when enablePayPalAppSwitch is false.
        // This ensures the JS SDK never attempts the native app switch path unless the
        // integrator has explicitly opted in, preserving backward-compatible behavior.
        let isPayPalAppSwitchAvailable = enablePayPalAppSwitch && application.isPayPalAppInstalled()

        let javascript = PopupBridgeUserScript(
            scheme: PopupBridgeConstants.callbackURLScheme,
            scriptMessageHandlerName: messageHandlerName,
            host: hostName,
            isVenmoInstalled: application.isVenmoAppInstalled(),
            isPayPalInstalled: isPayPalAppSwitchAvailable,
            returnURLScheme: resolveReturnURLScheme()
        ).rawJavascript

        let script = WKUserScript(
            source: javascript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        webView.configuration.userContentController.addUserScript(script)
    }

    /// Resolves the URL scheme used as the checkout return URL.
    ///
    /// Prefers the scheme explicitly provided in the initializer. When none is given, falls back to
    /// reading the first scheme from `CFBundleURLTypes` in the app's `Info.plist`. This fallback is
    /// best-effort: apps that register multiple URL schemes (e.g. Facebook, Google Sign-In) may have
    /// a third-party scheme listed first, so integrators should provide `returnURLScheme` explicitly.
    /// - Returns: The resolved return URL scheme, or `nil` if none could be determined.
    private func resolveReturnURLScheme() -> String? {
        if let returnURLScheme {
            return returnURLScheme
        }

        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return nil
        }

        for urlType in urlTypes {
            if let schemes = urlType["CFBundleURLSchemes"] as? [String], let scheme = schemes.first {
                return scheme
            }
        }

        return nil
    }

    private func injectWebView(webView: WKWebView, withJavaScript script: String) {
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                NSLog("Error: PopupBridge requires onComplete callback. Details: %@", error.localizedDescription)
            }
        }
    }
    
    // MARK: - WKScriptMessageHandler conformance
    
    /// :nodoc: This method is not covered by Semantic Versioning. Do not use.
    ///
    /// Called when the webpage sends a JavaScript message back to the native app
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == messageHandlerName,
              let jsonData = try? JSONSerialization.data(withJSONObject: message.body),
              let script = try? JSONDecoder().decode(WebViewMessage.self, from: jsonData) else {
            return
        }

        if let launchAppURLString = script.launchPayPalAppSwitch, let launchAppURL = URL(string: launchAppURLString) {
            handlePayPalAppSwitch(url: launchAppURL)
        } else if let urlString = script.url, let url = URL(string: urlString) {
            startWebAuthenticationSession(url: url)
        }
    }

    // MARK: - Message Handling

    /// Attempts a native PayPal app switch for the given URL, falling back to a web authentication
    /// session if the app can't be launched.
    private func handlePayPalAppSwitch(url: URL) {
        Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.appLaunchStarted, sessionID: sessionID)
        application.openURL(url) { [weak self] success in
            guard let self else { return }

            if success {
                Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.appLaunchSucceeded, sessionID: self.sessionID)
                self.startObservingPayPalLaunchAppReturn()
            } else {
                self.handlePayPalAppSwitchFailure(url: url)
            }
        }
    }

    /// Handles a failed PayPal app launch: web URLs fall back to a web authentication session,
    /// anything else cancels the flow.
    private func handlePayPalAppSwitchFailure(url: URL) {
        Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.appLaunchFailed, sessionID: sessionID)

        let scheme = url.scheme?.lowercased()
        guard scheme == "https" || scheme == "http" else {
            Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.failed, sessionID: sessionID)
            injectWebView(webView: webView, withJavaScript: cancelOrCompleteScript)
            return
        }

        startWebAuthenticationSession(url: url)
    }

    /// Starts an `ASWebAuthenticationSession` for the URL, forwarding the return URL on success and
    /// cancelling the flow if the user dismisses the session.
    private func startWebAuthenticationSession(url: URL) {
        webAuthenticationSession.start(url: url, context: self) { [weak self] url, _ in
            guard let self, let url, let returnBlock = self.returnBlock else { return }
            self.returnedWithURL = true
            returnBlock(url)
        } sessionDidCancel: { [weak self] in
            guard let self else { return }
            Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.canceled, sessionID: self.sessionID)
            self.injectWebView(webView: self.webView, withJavaScript: self.cancelOrCompleteScript)
        }
    }

    /// JS that invokes `onCancel` if the page defines it, otherwise completes with no payload or error.
    private var cancelOrCompleteScript: String {
        """
        if (typeof window.popupBridge.onCancel === 'function') {\
            window.popupBridge.onCancel();\
        } else {\
            window.popupBridge.onComplete(null, null);\
        }
        """
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding conformance

extension POPPopupBridge: ASWebAuthenticationPresentationContextProviding {

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = firstScene?.windows.first { $0.isKeyWindow }
        return window ?? ASPresentationAnchor()
    }
}
