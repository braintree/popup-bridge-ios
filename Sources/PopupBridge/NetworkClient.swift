import Foundation

protocol Networkable {
    func post<T: Encodable>(url: URL, body: T) async throws
}

final class NetworkClient: Networkable {
    
    // MARK: - Private Properties
    
    private let session: Sessionable
    
    // MARK: - Initializer
    
    init(session: Sessionable = URLSession.shared) {
        self.session = session
    }
    
    // MARK: - Internal Methods
    
    func post<T: Encodable>(url: URL, body: T) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = ["Content-Type": "application/json"]
        
        do {
            let encodedBody = try JSONEncoder().encode(body)
            request.httpBody = encodedBody
        } catch let encodingError {
            throw NetworkError.encodingError(encodingError)
        }
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
    }
}
