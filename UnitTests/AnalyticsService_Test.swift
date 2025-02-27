@testable import PopupBridge
import XCTest

class AnalyticsService_Test: XCTestCase {
    
    var sut: AnalyticsService!
    var mockNetworkClient: MockNetworkClient!
    
    override func setUp() {
        super.setUp()
        mockNetworkClient = MockNetworkClient()
        sut = AnalyticsService(networkClient: mockNetworkClient)
    }
    
    override func tearDown() {
        sut = nil
        mockNetworkClient = nil
        super.tearDown()
    }
    
    func testPerformEventRequest() async {
        await sut.performEventRequest("some-event", sessionID: "some-session-id")
        
        XCTAssertEqual(mockNetworkClient.lastURL, URL(string: "https://api.paypal.com/v1/tracking/batch/events"))
        XCTAssertNotNil(mockNetworkClient.lastBody)
    }
    
    func testPerformEventRequest_handlesError() async {
        mockNetworkClient.throwError = NetworkError.invalidResponse
        
        await sut.performEventRequest("some-event", sessionID: "some-session-id")
        
        XCTAssertEqual(mockNetworkClient.lastURL, URL(string: "https://api.paypal.com/v1/tracking/batch/events"))
        XCTAssertNotNil(mockNetworkClient.lastBody)
    }
}
