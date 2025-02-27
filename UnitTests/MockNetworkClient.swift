import Foundation
@testable import PopupBridge

class MockNetworkClient: Networkable {
    var lastURL: URL?
    var lastBody: Encodable?
    var throwError: Error?
    
    func post<T>(url: URL, body: T) async throws where T : Encodable {
        lastURL = url
        lastBody = body
        if let error = throwError {
            throw error
        }
    }
}
