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
    
    private let enablePopupBridgeAppSwitch: Bool
    private let returnURLScheme: String?
    private var webAuthenticationSession: WebAuthenticationSession = WebAuthenticationSession()
    private var returnBlock: ((URL) -> Void)? = nil
    private var launchAppReturnObserver: NSObjectProtocol?

    // MARK: - Initializers
        
    /// Initialize a Popup Bridge.
    /// - Parameters:
    ///   - webView: The web view to add a script message handler to. Do not change the web view's configuration or user content controller after initializing Popup Bridge.
    ///   - prefersEphemeralWebBrowserSession: A Boolean that, when true, requests that the browser does not share cookies
    ///   or other browsing data between the authenthication session and the user's normal browser session.
    ///   Defaults to `true`.
    ///   - enablePopupBridgeAppSwitch: When true, allows the SDK to launch the native PayPal app for checkout
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
    ///           name: Notification.Name(PopupBridgeConstants.notificationName),
    ///           object: nil,
    ///           userInfo: ["url": url]
    ///       )
    ///   }
    ///   ```
    ///   - returnURLScheme: The URL scheme registered in the app's `Info.plist` that PopupBridge should
    ///   use as the return URL for the checkout flow. If `nil`, PopupBridge will attempt to read the first
    ///   scheme from `CFBundleURLTypes`. Providing this value explicitly is recommended when the app
    ///   registers multiple URL schemes (e.g. Facebook, Google Sign-In).
    public init(webView: WKWebView, prefersEphemeralWebBrowserSession: Bool = true, enablePopupBridgeAppSwitch: Bool = false, returnURLScheme: String? = nil) {
        self.webView = webView
        self.application = UIApplication.shared
        self.enablePopupBridgeAppSwitch = enablePopupBridgeAppSwitch
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
        enablePopupBridgeAppSwitch: Bool = false,
        application: URLOpener
    ) {
        self.init(webView: webView, enablePopupBridgeAppSwitch: enablePopupBridgeAppSwitch, application: application)
        self.webAuthenticationSession = webAuthenticationSession
    }

    /// Internal designated init that accepts a URLOpener for testing
    init(webView: WKWebView, prefersEphemeralWebBrowserSession: Bool = true, enablePopupBridgeAppSwitch: Bool = false, returnURLScheme: String? = nil, application: URLOpener) {
        self.webView = webView
        self.application = application
        self.enablePopupBridgeAppSwitch = enablePopupBridgeAppSwitch
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
        if let launchAppReturnObserver {
            NotificationCenter.default.removeObserver(launchAppReturnObserver)
        }
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
    }
    
    // MARK: - Launch App Return Handling

    /// Starts listening for the return URL notification posted by the host app's SceneDelegate.
    /// Called only after a successful launchApp; removed after handling.
    private func startObservingLaunchAppReturn() {
        if let launchAppReturnObserver {
            NotificationCenter.default.removeObserver(launchAppReturnObserver)
        }

        launchAppReturnObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(PopupBridgeConstants.notificationName),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else {
                return
            }

            guard let url = notification.userInfo?["url"] as? URL else {
                return
            }

            self.handleLaunchAppReturn(url: url)
        }
    }

    /// Parses the return URL and injects `window.popupBridge.onComplete()` into the WebView.
    /// The return URL may include fragment-based data:
    ///   merchantapp://popupbridgev1/onApprove#onApprove&PayerID=XXX&token=EC-YYY
    /// Popup Bridge JavaScript is responsible for normalizing `path`, `queryItems`, and `hash`.
    private func handleLaunchAppReturn(url: URL) {
        if let launchAppReturnObserver {
            NotificationCenter.default.removeObserver(launchAppReturnObserver)
            self.launchAppReturnObserver = nil
        }

        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }

        let queryItems = urlComponents.queryItems?.reduce(into: [String: String]()) { partialResult, queryItem in
            partialResult[queryItem.name] = queryItem.value
        } ?? [:]

        let payload = URLDetailsPayload(
            path: urlComponents.path,
            queryItems: queryItems,
            hash: urlComponents.fragment
        )

        if let payloadData = try? JSONEncoder().encode(payload),
            let payloadString = String(data: payloadData, encoding: .utf8) {
            Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.succeeded, sessionID: sessionID)

            // The leading semicolon is a defensive IIFE guard: if the previous JS statement
            // on the page was left without a semicolon, concatenating a bare `(function(){…})()`
            // would be parsed as a function-call on that expression and throw. The `;` ensures
            // a clean statement boundary regardless of surrounding page JS.
            let script = """
                ;(function() {
                    if (typeof window.popupBridge !== 'undefined' && typeof window.popupBridge.onComplete === 'function') {
                        window.popupBridge.onComplete(null, \(payloadString));
                    } else {
                        if (!window.popupBridge) { window.popupBridge = {}; }
                        window.popupBridge.__pendingResult = \(payloadString);
                    }
                })();
            """
            injectWebView(webView: webView, withJavaScript: script)
        } else {
            let errorMessage = "Failed to serialize return URL payload as JSON."
            let errorResponse = "new Error(\"\(errorMessage)\")"
            Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.failed, sessionID: sessionID)
            let script = "window.popupBridge.onComplete(\(errorResponse), null);"
            injectWebView(webView: webView, withJavaScript: script)
        }
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

        let queryItems = urlComponents.queryItems?.reduce(into: [:]) { partialResult, queryItem in
            partialResult[queryItem.name] = queryItem.value
        }

        let payload = URLDetailsPayload(
            path: urlComponents.path,
            queryItems: queryItems ?? [:],
            hash: urlComponents.fragment
        )

        if let payloadData = try? JSONEncoder().encode(payload),
            let payload = String(data: payloadData, encoding: .utf8) {
            Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.succeeded, sessionID: sessionID)
            return "window.popupBridge.onComplete(null, \(payload));"
        } else {
            let errorMessage = "Failed to serialize return URL payload as JSON."
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
        
        let isPayPalInstalled = enablePopupBridgeAppSwitch && application.isPayPalAppInstalled()

        // Use the explicitly provided scheme, or fall back to reading from Info.plist.
        // Reading from Info.plist is a best-effort fallback: apps that register multiple URL
        // schemes (e.g. Facebook, Google Sign-In) may have a third-party scheme listed first,
        // so integrators should provide returnURLScheme explicitly in the initializer.
        let resolvedReturnURLScheme: String? = returnURLScheme ?? {
            guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
                return nil
            }
            for urlType in urlTypes {
                if let schemes = urlType["CFBundleURLSchemes"] as? [String], let scheme = schemes.first {
                    return scheme
                }
            }
            return nil
        }()

        let javascript = PopupBridgeUserScript(
            scheme: PopupBridgeConstants.callbackURLScheme,
            scriptMessageHandlerName: messageHandlerName,
            host: hostName,
            isVenmoInstalled: application.isVenmoAppInstalled(),
            isPayPalInstalled: isPayPalInstalled,
            returnURLScheme: resolvedReturnURLScheme
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
        if message.name == messageHandlerName {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: message.body),
                  let script = try? JSONDecoder().decode(WebViewMessage.self, from: jsonData) else {
                return
            }

            if let launchAppURLString = script.launchApp, let launchAppURL = URL(string: launchAppURLString) {
                Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.appLaunchStarted, sessionID: sessionID)
                application.openURL(launchAppURL) { [weak self] success in
                    guard let self else { return }
                    
                    if success {
                        Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.appLaunchSucceeded, sessionID: self.sessionID)
                        self.startObservingLaunchAppReturn()
                    } else {
                        Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.appLaunchFailed, sessionID: self.sessionID)
                        let cancelScript = """
                            if (typeof window.popupBridge.onCancel === 'function') {\
                                window.popupBridge.onCancel();\
                            } else {\
                                window.popupBridge.onComplete(null, null);\
                            }
                        """
                        let scheme = launchAppURL.scheme?.lowercased()
                        guard scheme == "https" || scheme == "http" else {
                            Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.canceled, sessionID: self.sessionID)
                            self.injectWebView(webView: self.webView, withJavaScript: cancelScript)
                            return
                        }
                        self.webAuthenticationSession.start(url: launchAppURL, context: self) { url, _ in
                            if let url, let returnBlock = self.returnBlock {
                                self.returnedWithURL = true
                                returnBlock(url)
                            }
                        } sessionDidCancel: {
                            Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.canceled, sessionID: self.sessionID)
                            self.injectWebView(webView: self.webView, withJavaScript: cancelScript)
                        }
                    }
                }
            } else if let urlString = script.url, let url = URL(string: urlString) {
                webAuthenticationSession.start(url: url, context: self) { url, _ in
                    if let url, let returnBlock = self.returnBlock {
                        self.returnedWithURL = true
                        returnBlock(url)
                        return
                    }
                } sessionDidCancel: { [self] in
                    let script = """
                        if (typeof window.popupBridge.onCancel === 'function') {\
                            window.popupBridge.onCancel();\
                        } else {\
                            window.popupBridge.onComplete(null, null);\
                        }
                    """

                    Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.canceled, sessionID: sessionID)

                    injectWebView(webView: webView, withJavaScript: script)
                    return
                }
            }
        }
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
