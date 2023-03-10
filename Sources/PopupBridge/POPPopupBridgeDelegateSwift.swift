import Foundation

/// Set a delegate to handle various events the "popup" lifecycle.
@objc public protocol POPPopupBridgeDelegateSwift : NSObjectProtocol {
    
    /// Popup Bridge will provide a Safari View Controller to your delegate.
    /// You must present the view controller in this method.
    @objc func popupBridge(_ bridge: POPPopupBridgeSwift, requestsPresentationOfViewController viewController: UIViewController)

    /// You must dismiss the view controller in this method.
    @objc func popupBridge(_ bridge: POPPopupBridgeSwift, requestsDismissalOfViewController viewController: UIViewController)
    
    /// Optional: Receive the URL that will be opened
    @objc optional func popupBridge(_ bridge: POPPopupBridgeSwift, willOpenURL url: URL)

    /// Optional: Receive messages from the web view
    @objc optional func popupBridge(_ bridge: POPPopupBridgeSwift, receivedMessage messageName: String, data: String?)
}
