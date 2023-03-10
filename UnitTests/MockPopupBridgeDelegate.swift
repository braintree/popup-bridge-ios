import UIKit
import PopupBridge

public class MockPopupBridgeDelegate: NSObject, POPPopupBridgeDelegate {
    
    override init() { }
    
    public func popupBridge(_ bridge: PopupBridge.POPPopupBridge, requestsPresentationOfViewController viewController: UIViewController) {
        //
    }
    
    public func popupBridge(_ bridge: PopupBridge.POPPopupBridge, requestsDismissalOfViewController viewController: UIViewController) {
        //
    }
    
}
