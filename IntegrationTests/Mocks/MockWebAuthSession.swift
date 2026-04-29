import AuthenticationServices
@testable import PopupBridge

final class MockWebAuthSession: WebAuthenticationSession {

    var startWasCalled = false
    var capturedURL: URL?

    override func start(
        url: URL,
        context: ASWebAuthenticationPresentationContextProviding,
        sessionDidComplete: @escaping (URL?, Error?) -> Void,
        sessionDidCancel: @escaping () -> Void
    ) {
        startWasCalled = true
        capturedURL = url
    }
}
