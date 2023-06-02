import UIKit
@testable import PopupBridge

class MockPopupBridgeDelegate: NSObject, POPPopupBridgeDelegate {

    var receivedMessage: String = ""
    var recievedData: String? = nil

    func popupBridge(_ bridge: POPPopupBridge, receivedMessage messageName: String, data: String?) {
        receivedMessage = messageName
        recievedData = data
    }
}
