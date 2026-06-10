import Foundation

/// Encapsulates the PayPal app switch flow: launching the native PayPal app, observing the deep-link
/// return posted by the host app's `SceneDelegate`, validating it, and building the JavaScript that
/// completes the checkout in the WebView.
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
    private let returnURLScheme: String?
    private let sessionID: String
    private let analyticsService: AnalyticsServiceable
    private let onComplete: (String) -> Void
    private let onLaunchFailed: (URL) -> Void

    private var returnObserver: NSObjectProtocol?

    init(
        application: URLOpener,
        returnURLScheme: String?,
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
        stopObserving()
    }

    // MARK: - Coordinator Queries

    /// The URL scheme used as the checkout return URL, advertised to the JS layer.
    var resolvedReturnURLScheme: String? {
        resolveReturnURLScheme()
    }

    /// Whether the PayPal app is installed and can be switched to.
    func isPayPalAppInstalled() -> Bool {
        application.isPayPalAppInstalled()
    }

    // MARK: - Launch

    /// Attempts a native PayPal app switch for the given URL. On success, starts observing the
    /// SceneDelegate return; on failure, reports back so the coordinator can fall back or cancel.
    func launch(url: URL) {
        analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.appLaunchStarted, sessionID: sessionID)
        application.openURL(url) { [weak self] success in
            guard let self else { return }

            if success {
                self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.appLaunchSucceeded, sessionID: self.sessionID)
                self.startObserving()
            } else {
                self.analyticsService.sendAnalyticsEvent(PopupBridgeAnalytics.appLaunchFailed, sessionID: self.sessionID)
                self.onLaunchFailed(url)
            }
        }
    }

    // MARK: - Return Handling

    /// Starts listening for the return URL notification posted by the host app's SceneDelegate.
    /// Called only after a successful launch; removed after handling.
    private func startObserving() {
        stopObserving()

        returnObserver = NotificationCenter.default.addObserver(
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

    /// Removes the one-shot return observer, if registered.
    private func stopObserving() {
        if let returnObserver {
            NotificationCenter.default.removeObserver(returnObserver)
            self.returnObserver = nil
        }
    }

    /// Exposed for testing
    ///
    /// Parses the return URL and produces the `window.popupBridge.onComplete()` JavaScript for the
    /// WebView. The return URL may include fragment-based data:
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
        stopObserving()
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
    /// Validates that a URL delivered via `PopupBridgeConstants.notificationName` is an actual
    /// PopupBridge return URL, rather than arbitrary data posted to that notification by other
    /// code in the host app. Mirrors the scheme/host check on the `ASWebAuthenticationSession` path.
    /// - Parameter components: the components of the URL received from the return notification.
    /// - Returns: `true` if the URL matches the expected PopupBridge return URL signature.
    func isValidPayPalReturnURL(_ components: URLComponents) -> Bool {
        // Host must be the PopupBridge host (e.g. popupbridgev1).
        guard components.host?.caseInsensitiveCompare(PopupBridgeConstants.host) == .orderedSame else {
            return false
        }

        // Scheme must match the return URL scheme PopupBridge advertised to PayPal. When a scheme
        // can be resolved, enforce it so URLs minted for other schemes are rejected.
        guard let expectedScheme = resolveReturnURLScheme() else {
            return false
        }

        return components.scheme?.caseInsensitiveCompare(expectedScheme) == .orderedSame
    }

    // MARK: - Return URL Scheme

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
}
