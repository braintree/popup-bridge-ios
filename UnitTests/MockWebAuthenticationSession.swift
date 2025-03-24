import Foundation
import AuthenticationServices
@testable import PopupBridge

class MockWebAuthenticationSession: WebAuthenticationSession {
    var cannedResponseURL: URL?
    var cannedErrorResponse: Error?
    var shouldCancel: Bool = false

    override func start(
        url: URL,
        context: ASWebAuthenticationPresentationContextProviding,
        sessionDidComplete: @escaping (URL?, Error?) -> Void,
        sessionDidCancel: @escaping () -> Void
    ) {
        if shouldCancel {
            sessionDidCancel()
        } else {
            sessionDidComplete(cannedResponseURL, cannedErrorResponse)
        }
    }
}
