import Foundation

/// Encapsulates the PayPal app switch flow: launching the native PayPal app, handling the deep-link
/// return routed from the host app's `SceneDelegate` via `PopupBridgeAppContextSwitcher`, validating
/// it, and building the JavaScript that completes the checkout in the WebView.
///
/// This is intentionally PayPal-specific — Venmo has no app switch logic in this SDK, it only reports
/// a flag to the JS layer. Keeping this flow here lets `POPPopupBridge` stay a thin coordinator.
///
/// It communicates back to the coordinator via two closures rather than owning the WebView or the
/// web authentication session:
///   - `onComplete`: the coordinator injects the provided JavaScript into the WebView.
///   - `onLaunchFailed`: the native launch failed; the coordinator decides whether to fall back to a
///     web authentication session or cancel the flow.
final class PayPalAppSwitchHandler {

    private let application: URLOpener

    /// The URL scheme used as the checkout return URL, advertised to the JS layer. Always non-`nil`:
    /// the handler is only created for the PayPal app switch flow, which requires an explicit scheme.
    let returnURLScheme: String

    private let sessionID: String
    private let analyticsService: AnalyticsServiceable
    private let onComplete: (String) -> Void
    private let onLaunchFailed: (URL) -> Void

    init(
        application: URLOpener,
        returnURLScheme: String,
        sessionID: String,
        analyticsService: AnalyticsServiceable,
        onComplete: @escaping (String) -> Void,
        onLaunchFailed: @escaping (URL) -> Void
    ) {
        self.application = application
        self.returnURLScheme = returnURLScheme
        self.sessionID = sessionID
        self.analyticsService = analyticsService
        self.onComplete = onComplete
        self.onLaunchFailed = onLaunchFailed
    }

    deinit {
        PopupBridgeAppContextSwitcher.shared.unregister(self)
    }

    // MARK: - Coordinator Queries

    func isPayPalAppInstalled() -> Bool {
        application.isPayPalAppInstalled()
    }

    // MARK: - Launch

    /// Attempts a native PayPal app switch for the given URL. On success, registers as the pending
    /// handler so the SceneDelegate return can be routed back via `PopupBridgeAppContextSwitcher`;
    /// on failure, reports back so the coordinator can fall back or cancel.
    func launch(url: URL) {
        analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.appSwitchStarted, sessionID: sessionID)
        application.openURL(url) { [weak self] success in
            guard let self else { return }

            if success {
                self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.appSwitchSucceeded, sessionID: self.sessionID)
                PopupBridgeAppContextSwitcher.shared.register(self)
            } else {
                self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.appSwitchFailed, sessionID: self.sessionID)
                self.onLaunchFailed(url)
            }
        }
    }

    // MARK: - Return Handling

    /// Exposed for testing
    ///
    /// Handles a return URL routed in from `PopupBridgeAppContextSwitcher`. Parses the URL and
    /// produces the `window.popupBridge.onComplete()` JavaScript for the WebView. The return URL may
    /// include fragment-based data:
    ///   merchantapp://popupbridgev1/onApprove#onApprove&PayerID=XXX&token=EC-YYY
    /// Popup Bridge JavaScript is responsible for normalizing `path`, `queryItems`, and `hash`.
    func handlePayPalLaunchAppReturn(url: URL) {
        // Defense in depth: the switcher only routes URLs that pass canHandleReturnURL, but re-check
        // here so this entry point is safe regardless of caller. A non-matching URL is ignored
        // without clearing the pending registration, so a later legitimate return still completes.
        guard canHandleReturnURL(url),
              let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }

        // Valid return: clear the one-shot registration, then forward the result to the WebView.
        PopupBridgeAppContextSwitcher.shared.unregister(self)
        injectReturnResult(URLDetailsPayload(components: urlComponents))
    }

    /// Serializes the payload and forwards the completion JS to the coordinator, emitting the matching analytics event.
    private func injectReturnResult(_ payload: URLDetailsPayload) {
        guard let payloadData = try? JSONEncoder().encode(payload),
              let payloadString = String(data: payloadData, encoding: .utf8) else {
            analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.failed, sessionID: sessionID)
            let errorResponse = "new Error(\"Failed to serialize return URL payload as JSON.\")"
            onComplete("window.popupBridge.onComplete(\(errorResponse), null);")
            return
        }

        analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.succeeded, sessionID: sessionID)
        onComplete(payPalReturnCompletionScript(payloadString: payloadString))
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
    /// Routing check: returns whether this handler recognizes `url` as its PopupBridge return URL.
    /// `PopupBridgeAppContextSwitcher` uses it to decide whether to route a SceneDelegate return
    /// here or report it as unhandled (so the integrator can chain to other app-switch handlers).
    /// Mirrors the scheme/host check on the `ASWebAuthenticationSession` path.
    /// - Parameter url: the URL received from the host app's SceneDelegate.
    /// - Returns: `true` if the URL matches the expected PopupBridge return URL signature.
    func canHandleReturnURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        // Host must be the PopupBridge host (e.g. popupbridgev1).
        guard components.host?.caseInsensitiveCompare(PopupBridgeConstants.host) == .orderedSame else {
            return false
        }

        // Scheme must match the return URL scheme PopupBridge advertised to PayPal, so URLs minted for
        // other schemes are rejected.
        return components.scheme?.caseInsensitiveCompare(returnURLScheme) == .orderedSame
    }
}
