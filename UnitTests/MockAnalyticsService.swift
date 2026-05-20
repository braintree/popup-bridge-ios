import Foundation
@testable import PopupBridge

class MockAnalyticsService: AnalyticsServiceable {
    
    var lastEventName: String?
    var lastSessionID: String?
    var eventCount = 0
    var sentEventNames: [String] = []

    func sendAnalyticsEvent(_ eventName: String, sessionID: String) {
        lastEventName = eventName
        lastSessionID = sessionID
        eventCount += 1
        sentEventNames.append(eventName)
    }
}
