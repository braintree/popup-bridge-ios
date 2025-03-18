import Foundation

protocol AnalyticsServiceable {
    func sendAnalyticsEvent(_ eventName: String, sessionID: String)
}

final class AnalyticsService: AnalyticsServiceable {
    
    // MARK: - Private Properties
    
    /// The FPTI URL to post all analytic events.
    private let url = URL(string: "https://api.paypal.com/v1/tracking/batch/events")!
    private let session: Sessionable
    
    // MARK: - Initializer
    
    init(session: Sessionable = URLSession.shared) {
        self.session = session
    }
    
    // MARK: - Internal Methods
    
    func sendAnalyticsEvent(_ eventName: String, sessionID: String) {
        Task(priority: .background) {
            await performEventRequest(eventName, sessionID: sessionID)
        }
    }
    
    func performEventRequest(_ eventName: String, sessionID: String) async {
        let body = createAnalyticsEvent(eventName: eventName, sessionID: sessionID)
        do {
            try await post(url: url, body: body)
        } catch {
            NSLog("[PopupBridge SDK] Failed to send analytics: %@", error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    /// Constructs POST params to be sent to FPTI
    private func createAnalyticsEvent(eventName: String, sessionID: String) -> FPTIBatchData {
        let batchMetadata = FPTIBatchData.Metadata(sessionID: sessionID)
        let event = FPTIBatchData.Event(eventName: eventName)
        return FPTIBatchData(metadata: batchMetadata, events: [event])
    }
    
    private func post(url: URL, body: FPTIBatchData) async throws {
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
