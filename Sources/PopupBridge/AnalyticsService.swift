import Foundation

protocol AnalyticsServiceable {
    func sendAnalyticsEvent(_ eventName: String, sessionID: String)
}

final class AnalyticsService: AnalyticsServiceable {
    
    // MARK: - Private Properties
    
    /// The FPTI URL to post all analytic events.
    private let url = URL(string: "https://api.paypal.com/v1/tracking/batch/events")!
    private let networkClient: Networkable
    
    // MARK: - Initializer
    
    init(networkClient: Networkable = NetworkClient()) {
        self.networkClient = networkClient
    }
    
    // MARK: - Internal Methods
    
    func sendAnalyticsEvent(_ eventName: String, sessionID: String) {
        Task(priority: .background) {
            await performEventRequest(eventName, sessionID: sessionID)
        }
    }
    
    func performEventRequest(_ eventName: String, sessionID: String) async {
        let body = createAnalyticsEvent(eventName: eventName, sessionID: sessionID)
        try? await networkClient.post(url: url, body: body)
    }
    
    // MARK: - Private Methods
    
    /// Constructs POST params to be sent to FPTI
    private func createAnalyticsEvent(eventName: String, sessionID: String) -> FPTIBatchData {
        let batchMetadata = FPTIBatchData.Metadata(sessionID: sessionID)
        let event = FPTIBatchData.Event(eventName: eventName)
        return FPTIBatchData(metadata: batchMetadata, events: [event])
    }
}
