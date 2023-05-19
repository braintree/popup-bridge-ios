import UIKit

/// Set a delegate to handle various events the "popup" lifecycle.
@objc public protocol POPPopupBridgeDelegate: NSObjectProtocol {

    /// Optional: Receive messages from the web view
    @objc optional func popupBridge(_ bridge: POPPopupBridge, receivedMessage messageName: String, data: String?)
}
