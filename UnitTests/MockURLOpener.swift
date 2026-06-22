import Foundation
@testable import PopupBridge

class MockURLOpener: URLOpener {

    var venmoInstalled = false

    func isVenmoAppInstalled() -> Bool {
        venmoInstalled
    }
}
