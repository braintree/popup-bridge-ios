import Foundation
@testable import PopupBridge

class MockAnalyticsService: AnalyticsServiceable {
    
    func sendAnalyticsEvent(_ eventName: String, sessionID: String) {
        // TODO: Add mock validations
    }
}
