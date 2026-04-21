import Foundation
@testable import PopupBridge

class MockURLOpener: URLOpener {

    var venmoInstalled = false
    var payPalInstalled = false
    var openURLSuccess = true
    var lastOpenedURL: URL?

    func isVenmoAppInstalled() -> Bool {
        venmoInstalled
    }

    func isPayPalAppInstalled() -> Bool {
        payPalInstalled
    }

    func openURL(_ url: URL, completionHandler: @escaping (Bool) -> Void) {
        lastOpenedURL = url
        completionHandler(openURLSuccess)
    }
}
