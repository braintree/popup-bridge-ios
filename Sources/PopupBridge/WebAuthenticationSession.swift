import Foundation
import AuthenticationServices

class WebAuthenticationSession: NSObject {

    let callbackURLScheme: String = "sdk.ios.popup-bridge"

    var authenticationSession: ASWebAuthenticationSession?

    func start(
        url: URL,
        context: ASWebAuthenticationPresentationContextProviding,
        completion: @escaping (URL?, Error?) -> Void
    ) {
        self.authenticationSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackURLScheme,
            completionHandler: completion
        )

        authenticationSession?.prefersEphemeralWebBrowserSession = true
        authenticationSession?.presentationContextProvider = context

        authenticationSession?.start()
    }
}
