@testable import PopupBridge
import XCTest

class AnalyticsService_Test: XCTestCase {
    
    var sut: AnalyticsService!
    var mockSession: MockSession!
    
    let eventName = "some-event-name"
    let sessionID = "some-session-id"
    let testURL = URL(string: "https://api.paypal.com/v1/tracking/batch/events")!
    
    override func setUp() {
        super.setUp()
        mockSession = MockSession()
        sut = AnalyticsService(session: mockSession)
    }
    
    override func tearDown() {
        sut = nil
        mockSession = nil
        super.tearDown()
    }
    
    func testPerformEventRequest_handleSuccess() async {
        mockSession.response = (data: Data(), response: HTTPURLResponse(url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        
        await sut.performEventRequest(eventName, sessionID: sessionID)

        let decodedResponse = decodeData(mockSession.requestedBody!)
        
        XCTAssertEqual(mockSession.requestedURL, testURL)
        XCTAssertEqual(mockSession.requestHttpMethod, "POST")
        XCTAssertEqual(mockSession.requestAllHTTPHeaderFields, ["Content-Type": "application/json"])
        XCTAssertEqual(decodedResponse?.events.first?.fptiEvents.first?.eventName, eventName)
        XCTAssertEqual(decodedResponse?.events.first?.metadata.sessionID, sessionID)
    }
    
    func decodeData(_ data: Data) -> FPTIBatchData? {
        let decoder = JSONDecoder()
        do {
            let event = try decoder.decode(FPTIBatchData.self, from: data)
            return event
        } catch {
            return nil
        }
    }
}
