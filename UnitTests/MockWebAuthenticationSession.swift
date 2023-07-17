import Foundation
import AuthenticationServices
@testable import PopupBridge

class MockWebAuthenticationSession: WebAuthenticationSession {
    var cannedResponseURL: URL?
    var cannedErrorResponse: Error?

    override func start(
        url: URL,
        context: ASWebAuthenticationPresentationContextProviding,
        sessionDidComplete: @escaping (URL?, Error?) -> Void,
        sessionDidCancel: @escaping () -> Void
    ) {
        sessionDidComplete(cannedResponseURL, cannedErrorResponse)
    }
}
