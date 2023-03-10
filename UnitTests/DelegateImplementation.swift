import UIKit
import PopupBridge

// TODO: - Can we get rid of NSObj requirement
public class DelegateImplementation: NSObject, POPPopupBridgeDelegate {
    
    override init() { }
    
    public func popupBridge(_ bridge: PopupBridge.POPPopupBridgeSwift, requestsPresentationOfViewController viewController: UIViewController) {
        // fake implementation
    }
    
    public func popupBridge(_ bridge: PopupBridge.POPPopupBridgeSwift, requestsDismissalOfViewController viewController: UIViewController) {
        // fake implementation
    }
    
}
