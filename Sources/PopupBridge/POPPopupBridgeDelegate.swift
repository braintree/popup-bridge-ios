import UIKit

/// Set a delegate to handle various events the "popup" lifecycle.
@objc public protocol POPPopupBridgeDelegate: NSObjectProtocol {
    
    /// Popup Bridge will provide a Safari View Controller to your delegate.
    /// You must present the view controller in this method.
    @objc func popupBridge(_ bridge: POPPopupBridge, requestsPresentationOfViewController viewController: UIViewController)

    /// You must dismiss the view controller in this method.
    @objc func popupBridge(_ bridge: POPPopupBridge, requestsDismissalOfViewController viewController: UIViewController)
    
    /// Optional: Receive the URL that will be opened
    @objc optional func popupBridge(_ bridge: POPPopupBridge, willOpenURL url: URL)

    /// Optional: Receive messages from the web view
    @objc optional func popupBridge(_ bridge: POPPopupBridge, receivedMessage messageName: String, data: String?)
}
