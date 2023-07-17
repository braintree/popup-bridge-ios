import UIKit
@testable import PopupBridge

class MockPopupBridgeDelegate: NSObject, POPPopupBridgeDelegate {

    var didRequestPresentationOfViewController: Bool = false
    var didRequestDismissalOfViewController: Bool = false
    var receivedMessage: String = ""
    var recievedData: String? = nil

    func popupBridge(_ bridge: PopupBridge.POPPopupBridge, requestsPresentationOfViewController viewController: UIViewController) {
        didRequestPresentationOfViewController = true
    }

    func popupBridge(_ bridge: PopupBridge.POPPopupBridge, requestsDismissalOfViewController viewController: UIViewController) {
        didRequestDismissalOfViewController = true
    }

    func popupBridge(_ bridge: POPPopupBridge, receivedMessage messageName: String, data: String?) {
        receivedMessage = messageName
        recievedData = data
    }
}
