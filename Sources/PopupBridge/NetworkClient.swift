import Foundation

protocol Networkable {
    func post(url: URL, body: FPTIBatchData) async throws
}

final class NetworkClient: Networkable {
    
    // MARK: - Private Properties
    
    private let session: Sessionable
    
    // MARK: - Initializer
    
    init(session: Sessionable = URLSession.shared) {
        self.session = session
    }
    
    // MARK: - Internal Methods
    
    func post(url: URL, body: FPTIBatchData) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = ["Content-Type": "application/json"]
        
        let encodedBody = try JSONEncoder().encode(body)
        request.httpBody = encodedBody
            
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
    }
}
