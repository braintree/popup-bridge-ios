import Foundation
import AuthenticationServices

class WebAuthenticationSession: NSObject {

    var authenticationSession: ASWebAuthenticationSession?
    var prefersEphemeralWebBrowserSession: Bool = true
    var callbackURLScheme: String = PopupBridgeConstants.callbackURLScheme

    func start(
        url: URL,
        context: ASWebAuthenticationPresentationContextProviding,
        sessionDidComplete: @escaping (URL?, Error?) -> Void,
        sessionDidCancel: @escaping () -> Void
    ) {
        self.authenticationSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackURLScheme
        ) { url, error in
            if let error = error as? NSError, error.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                sessionDidCancel()
            } else {
                sessionDidComplete(url, error)
            }
        }
        authenticationSession?.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
        authenticationSession?.presentationContextProvider = context

        authenticationSession?.start()
    }
}
