import Foundation

/// Routes app-switch return URLs (delivered to the host app's `SceneDelegate`) to the PopupBridge
/// instance that is currently awaiting a PayPal app switch return.
///
/// This mirrors braintree_ios's `BTAppContextSwitcher.handleOpenURL(context:)` so merchants using
/// both SDKs follow a single, explicit pattern instead of posting to a global notification. Because
/// the return is delivered through this explicit call, there is no open broadcast channel for other
/// code in the host app to inject arbitrary URLs into.
@objcMembers
public class PopupBridgeAppContextSwitcher: NSObject {

    /// The shared instance used to route SceneDelegate return URLs into PopupBridge.
    public static let shared = PopupBridgeAppContextSwitcher()

    /// The PopupBridge app switch flow currently awaiting a return, if any. Weak so a deallocated
    /// bridge never keeps routing; cleared after a handled return (one-shot).
    weak var pendingHandler: PayPalAppSwitchHandler?

    override private init() {
        super.init()
    }

    /// Forwards a return URL (e.g. from `scene(_:openURLContexts:)`) to the pending PopupBridge
    /// app switch flow.
    /// - Parameter url: The deep-link URL the PayPal app returned to the host app.
    /// - Returns: `true` if a pending PopupBridge flow handled the URL; `false` otherwise, so the
    ///   integrator can chain the URL to other app-switch handlers (e.g. Braintree).
    @discardableResult
    public func handleReturnURL(_ url: URL) -> Bool {
        guard let handler = pendingHandler, handler.canHandleReturnURL(url) else {
            return false
        }

        handler.handlePayPalLaunchAppReturn(url: url)
        return true
    }

    /// Registers the handler awaiting an app switch return. Called after a successful native launch.
    func register(_ handler: PayPalAppSwitchHandler) {
        pendingHandler = handler
    }

    /// Clears the pending registration if it still points at `handler` (one-shot / deinit cleanup).
    func unregister(_ handler: PayPalAppSwitchHandler) {
        if pendingHandler === handler {
            pendingHandler = nil
        }
    }
}
