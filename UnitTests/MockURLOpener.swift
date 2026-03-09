import Foundation
@testable import PopupBridge

class MockURLOpener: URLOpener {

    var venmoInstalled = false
    var paypalInstalled = false
    var openURLSuccess = true
    var lastOpenedURL: URL?

    func isVenmoAppInstalled() -> Bool {
        venmoInstalled
    }

    func isPayPalAppInstalled() -> Bool {
        paypalInstalled
    }

    func openURL(_ url: URL, completionHandler: @escaping (Bool) -> Void) {
        lastOpenedURL = url
        completionHandler(openURLSuccess)
    }
}
