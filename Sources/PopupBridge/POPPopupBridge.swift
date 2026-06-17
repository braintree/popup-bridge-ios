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
    private let sessionID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    private let webView: WKWebView
    private var application: URLOpener = UIApplication.shared

    private var webAuthenticationSession: WebAuthenticationSession = WebAuthenticationSession()
    private var returnBlock: ((URL) -> Void)? = nil

    /// Owns the strictly PayPal app switch flow (native launch + SceneDelegate return handling),
    /// keeping `POPPopupBridge` a coordinator.
    private var appSwitchHandler: PayPalAppSwitchHandler?

    // MARK: - Initializers

    /// Initialize a Popup Bridge for the standard browser-based checkout flow.
    ///
    /// Use this initializer when you do not need the native PayPal app switch. To enable the PayPal app
    /// switch flow, use `init(webView:returnURLScheme:prefersEphemeralWebBrowserSession:)` instead.
    /// - Parameters:
    ///   - webView: The web view to add a script message handler to. Do not change the web view's
    ///   configuration or user content controller after initializing Popup Bridge.
    ///   - prefersEphemeralWebBrowserSession: A Boolean that, when true, requests that the browser does
    ///   not share cookies or other browsing data between the authentication session and the user's
    ///   normal browser session. Defaults to `true`.
    public convenience init(
        webView: WKWebView,
        prefersEphemeralWebBrowserSession: Bool = true
    ) {
        self.init(
            webView: webView,
            returnURLScheme: nil,
            prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession,
            application: UIApplication.shared,
            webAuthenticationSession: WebAuthenticationSession()
        )
    }

    /// Initialize a Popup Bridge with the native PayPal app switch flow enabled.
    ///
    /// Use this initializer to let the SDK launch the native PayPal app for checkout instead of opening a
    /// browser. Because the deep-link return arrives at the host app's `SceneDelegate` (outside the
    /// WebView), a `returnURLScheme` is **required** — there is no flag to toggle and no scheme guessing.
    ///
    /// **Required SceneDelegate integration:** the host app must forward incoming URLs from its
    /// `SceneDelegate` to PopupBridge via `PopupBridgeAppContextSwitcher.shared.handleReturnURL(_:)`,
    /// otherwise the checkout flow will hang indefinitely after the PayPal app returns. The method
    /// returns a `Bool` indicating whether PopupBridge handled the URL, so you can chain it to other
    /// app-switch handlers. In your `SceneDelegate`:
    /// ```swift
    /// func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    ///     guard let url = URLContexts.first?.url else { return }
    ///     PopupBridgeAppContextSwitcher.shared.handleReturnURL(url)
    /// }
    /// ```
    /// - Parameters:
    ///   - webView: The web view to add a script message handler to. Do not change the web view's
    ///   configuration or user content controller after initializing Popup Bridge.
    ///   - returnURLScheme: The URL scheme registered in the app's `Info.plist` that PopupBridge uses as
    ///   the return URL for the checkout flow. PopupBridge does not guess the scheme from
    ///   `CFBundleURLTypes`, since apps that register multiple URL schemes (e.g. Facebook, Google
    ///   Sign-In) would resolve the wrong one.
    ///   - prefersEphemeralWebBrowserSession: A Boolean that, when true, requests that the browser does
    ///   not share cookies or other browsing data between the authentication session and the user's
    ///   normal browser session. Defaults to `true`.
    public convenience init(
        webView: WKWebView,
        returnURLScheme: String,
        prefersEphemeralWebBrowserSession: Bool = true
    ) {
        self.init(
            webView: webView,
            returnURLScheme: returnURLScheme,
            prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession,
            application: UIApplication.shared,
            webAuthenticationSession: WebAuthenticationSession()
        )
    }

    /// Exposed for testing.
    ///
    /// Convenience initializer that injects a custom `WebAuthenticationSession` so tests can stub the
    /// browser authentication flow. App switch stays disabled (no `returnURLScheme`).
    convenience init(
        webView: WKWebView,
        webAuthenticationSession: WebAuthenticationSession
    ) {
        self.init(
            webView: webView,
            returnURLScheme: nil,
            prefersEphemeralWebBrowserSession: true,
            application: UIApplication.shared,
            webAuthenticationSession: webAuthenticationSession
        )
    }

    /// Exposed for testing.
    ///
    /// Convenience initializer that injects a custom `WebAuthenticationSession` and `URLOpener` and
    /// enables the PayPal app switch flow, letting tests exercise it end to end with mocked dependencies.
    convenience init(
        webView: WKWebView,
        webAuthenticationSession: WebAuthenticationSession,
        returnURLScheme: String,
        application: URLOpener
    ) {
        self.init(
            webView: webView,
            returnURLScheme: returnURLScheme,
            prefersEphemeralWebBrowserSession: true,
            application: application,
            webAuthenticationSession: webAuthenticationSession
        )
    }

    /// Designated initializer. A non-`nil` `returnURLScheme` selects the PayPal app switch flow; when it
    /// is `nil`, the standard browser-based flow is used and the native app switch path stays disabled.
    /// Private so the only public entry points are the two flow-specific initializers above, keeping the
    /// internal `URLOpener` out of the public API.
    private init(
        webView: WKWebView,
        returnURLScheme: String?,
        prefersEphemeralWebBrowserSession: Bool,
        application: URLOpener,
        webAuthenticationSession: WebAuthenticationSession
    ) {
        self.webView = webView
        self.application = application
        self.webAuthenticationSession = webAuthenticationSession

        super.init()

        self.appSwitchHandler = makeAppSwitchHandler(application: application, returnURLScheme: returnURLScheme)
        configureWebView()
        self.webAuthenticationSession.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession

        returnBlock = { [weak self] url in
            guard let script = self?.constructJavaScriptCompletionResult(returnURL: url) else {
                return
            }

            self?.injectWebView(webView: webView, withJavaScript: script)
            return
        }
    }

    deinit {
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
    }

    /// Builds the app switch handler, wiring its results back to this coordinator: completion JS is
    /// injected into the WebView, and a failed native launch falls back to a web authentication session.
    private func makeAppSwitchHandler(application: URLOpener, returnURLScheme: String?) -> PayPalAppSwitchHandler {
        PayPalAppSwitchHandler(
            application: application,
            returnURLScheme: returnURLScheme,
            sessionID: sessionID,
            analyticsService: Self.analyticsService,
            onComplete: { [weak self] script in
                guard let self else { return }
                self.injectWebView(webView: self.webView, withJavaScript: script)
            },
            onLaunchFailed: { [weak self] url in
                self?.handlePayPalAppSwitchFailure(url: url)
            }
        )
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
              urlComponents.host?.caseInsensitiveCompare(PopupBridgeConstants.host) == .orderedSame
        else {
            return nil
        }

        let payload = URLDetailsPayload(components: urlComponents)

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

        // App switch is available only when a returnURLScheme was provided (i.e. the integrator used the
        // PayPal app switch initializer) and the PayPal app is actually installed. Otherwise we report it
        // as absent to the JavaScript layer so the JS SDK never attempts the native app switch path,
        // preserving backward-compatible behavior for the standard browser flow.
        let isPayPalAppSwitchAvailable = appSwitchHandler?.resolvedReturnURLScheme != nil
            && (appSwitchHandler?.isPayPalAppInstalled() ?? false)

        let javascript = PopupBridgeUserScript(
            scheme: PopupBridgeConstants.callbackURLScheme,
            scriptMessageHandlerName: messageHandlerName,
            host: PopupBridgeConstants.host,
            isVenmoInstalled: application.isVenmoAppInstalled(),
            isPayPalInstalled: isPayPalAppSwitchAvailable,
            returnURLScheme: appSwitchHandler?.resolvedReturnURLScheme
        ).rawJavascript

        let script = WKUserScript(
            source: javascript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        webView.configuration.userContentController.addUserScript(script)
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
            appSwitchHandler?.launch(url: launchAppURL)
        } else if let urlString = script.url, let url = URL(string: urlString) {
            startWebAuthenticationSession(url: url)
        }
    }

    // MARK: - Message Handling

    /// Handles a failed PayPal app launch: web URLs fall back to a web authentication session,
    /// anything else cancels the flow.
    private func handlePayPalAppSwitchFailure(url: URL) {
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
