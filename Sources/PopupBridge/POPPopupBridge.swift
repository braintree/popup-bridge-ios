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
    private var application: URLOpener = UIApplication.shared
    
    private var webAuthenticationSession: WebAuthenticationSession = WebAuthenticationSession()
    private var returnBlock: ((URL) -> Void)? = nil
    private var launchAppReturnObserver: NSObjectProtocol?
    private var pendingLaunchAppResult: String?
    
    // MARK: - Initializers
        
    /// Initialize a Popup Bridge.
    /// - Parameters:
    ///   - webView: The web view to add a script message handler to. Do not change the web view's configuration or user content controller after initializing Popup Bridge.
    ///   - prefersEphemeralWebBrowserSession: A Boolean that, when true, requests that the browser does not share cookies
    ///   or other browsing data between the authenthication session and the user’s normal browser session.
    ///   Defaults to `true`.
    public init(webView: WKWebView, prefersEphemeralWebBrowserSession: Bool = true) {
        self.webView = webView

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
        application: URLOpener
    ) {
        self.init(webView: webView, application: application)
        self.webAuthenticationSession = webAuthenticationSession
    }

    /// Internal designated init that accepts a URLOpener for testing
    init(webView: WKWebView, prefersEphemeralWebBrowserSession: Bool = true, application: URLOpener) {
        self.webView = webView
        self.application = application

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
        if let observer = launchAppReturnObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
    }
    
    // MARK: - Launch App Return Handling

    /// Starts listening for the return URL notification posted by the host app's SceneDelegate.
    /// Called only after a successful launchApp; removed after handling.
    private func startObservingLaunchAppReturn() {
        // Remove any stale observer before adding a new one
        if let observer = launchAppReturnObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        launchAppReturnObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("popupBridgeReturnURL"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let url = notification.userInfo?["url"] as? URL else {
                return
            }
            self.handleLaunchAppReturn(url: url)
        }
    }

    /// Parses the return URL and injects `window.popupBridge.onComplete()` into the WebView.
    /// Venice uses fragment-based return for web_sdk integration:
    ///   merchantapp://popupbridgev1/onApprove#onApprove&PayerID=XXX&token=EC-YYY
    /// The fragment contains key=value pairs that must be merged into queryItems
    /// since the JS SDK reads result.queryItems (not result.hash).
    private func handleLaunchAppReturn(url: URL) {
        // One-shot: stop observing immediately
        if let observer = launchAppReturnObserver {
            NotificationCenter.default.removeObserver(observer)
            launchAppReturnObserver = nil
        }

        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }

        // Start with query string params (if any)
        var queryItems = urlComponents.queryItems?.reduce(into: [String: String]()) { partialResult, queryItem in
            partialResult[queryItem.name] = queryItem.value
        } ?? [:]

        // Parse fragment params (e.g. "onApprove&PayerID=XXX&token=EC-YYY") and merge
        if let fragment = urlComponents.fragment {
            let fragmentComponents = fragment.components(separatedBy: "&")
            for component in fragmentComponents {
                let parts = component.components(separatedBy: "=")
                if parts.count == 2 {
                    queryItems[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
                }
            }
        }

        // Map the path to the opType expected by the JS SDK's popup-bridge payment flow.
        // Venice returns /onApprove or /onCancel in the path; the JS SDK expects
        // opType "payment" or "cancel" respectively.
        if queryItems["opType"] == nil {
            let path = urlComponents.path.lowercased()
            if path.contains("onapprove") {
                queryItems["opType"] = "payment"
            } else if path.contains("oncancel") {
                queryItems["opType"] = "cancel"
            }
        }

        let payload = URLDetailsPayload(
            path: urlComponents.path,
            queryItems: queryItems,
            hash: urlComponents.fragment
        )

        if let payloadData = try? JSONEncoder().encode(payload),
           let payloadString = String(data: payloadData, encoding: .utf8) {
            Self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.succeeded, sessionID: sessionID)

            // Store result so it survives WKWebView content process termination.
            // Also inject a WKUserScript that will set __pendingResult on the
            // next page load, allowing the JS SDK to pick it up on re-init.
            pendingLaunchAppResult = payloadString
            let pendingJs = """
                ;(function() {
                    if (!window.popupBridge) { window.popupBridge = {}; }
                    window.popupBridge.__pendingResult = \(payloadString);
                })();
            """
            let pendingScript = WKUserScript(
                source: pendingJs,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            webView.configuration.userContentController.addUserScript(pendingScript)

            // Try immediate injection for the case where the page is still alive
            let script = """
                if (typeof window.popupBridge !== 'undefined' && typeof window.popupBridge.onComplete === 'function') {
                    window.popupBridge.onComplete(null, \(payloadString));
                }
            """
            injectWebView(webView: webView, withJavaScript: script)
        } else {
            let errorMessage = "Failed to parse query items from return URL."
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
        
        let isPayPalInstalled = application.isPayPalAppInstalled()
        Self.analyticsService.sendAnalyticsEvent(
            isPayPalInstalled ? PopupBridgeAnalytics.paypalInstalled : PopupBridgeAnalytics.paypalNotInstalled,
            sessionID: sessionID
        )

        let javascript = PopupBridgeUserScript(
            scheme: PopupBridgeConstants.callbackURLScheme,
            scriptMessageHandlerName: messageHandlerName,
            host: hostName,
            isVenmoInstalled: application.isVenmoAppInstalled(),
            isPayPalInstalled: isPayPalInstalled
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
                        self.webAuthenticationSession.start(url: launchAppURL, context: self) { url, _ in
                            if let url, let returnBlock = self.returnBlock {
                                self.returnedWithURL = true
                                returnBlock(url)
                            }
                        } sessionDidCancel: {
                            let cancelScript = """
                                if (typeof window.popupBridge.onCancel === 'function') {\
                                    window.popupBridge.onCancel();\
                                } else {\
                                    window.popupBridge.onComplete(null, null);\
                                }
                            """
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
