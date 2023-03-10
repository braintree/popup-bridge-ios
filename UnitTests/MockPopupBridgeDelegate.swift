import UIKit
import PopupBridge

// TODO: - Can we get rid of NSObj requirement
public class MockPopupBridgeDelegate: NSObject, POPPopupBridgeDelegate {
    
    override init() { }
    
    public func popupBridge(_ bridge: PopupBridge.POPPopupBridge, requestsPresentationOfViewController viewController: UIViewController) {
        //
    }
    
    public func popupBridge(_ bridge: PopupBridge.POPPopupBridge, requestsDismissalOfViewController viewController: UIViewController) {
        //
    }
    
}
