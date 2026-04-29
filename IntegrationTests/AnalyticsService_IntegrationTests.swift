import XCTest
@testable import PopupBridge

final class AnalyticsService_IntegrationTests: XCTestCase {

    var sut: AnalyticsService!

    let eventName = "test-integration-event"
    let sessionID = "test-integration-session-id"
    let analyticsURL = URL(string: "https://api.paypal.com/v1/tracking/batch/events")!

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        sut = AnalyticsService(session: URLSession(configuration: config))
    }

    override func tearDown() {
        sut = nil
        StubURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - performEventRequest

    func test_performEventRequest_success_postsToCorrectEndpointWithCorrectPayload() async {
        StubURLProtocol.stubbedStatusCode = 200

        await sut.performEventRequest(eventName, sessionID: sessionID)

        XCTAssertEqual(StubURLProtocol.lastRequest?.url, analyticsURL)
        XCTAssertEqual(StubURLProtocol.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(StubURLProtocol.lastRequest?.allHTTPHeaderFields?["Content-Type"], "application/json")

        guard let body = StubURLProtocol.lastRequest?.httpBody,
              let decoded = try? JSONDecoder().decode(FPTIBatchData.self, from: body) else {
            XCTFail("Request body could not be decoded as FPTIBatchData")
            return
        }
        XCTAssertEqual(decoded.events.first?.fptiEvents.first?.eventName, eventName)
        XCTAssertEqual(decoded.events.first?.metadata.sessionID, sessionID)
    }

    func test_performEventRequest_nonSuccessResponse_doesNotPropagateError() async {
        StubURLProtocol.stubbedStatusCode = 400

        await sut.performEventRequest(eventName, sessionID: sessionID)

        XCTAssertNotNil(StubURLProtocol.lastRequest, "Request should have been sent despite error response")
    }

    func test_performEventRequest_serverError_doesNotPropagateError() async {
        StubURLProtocol.stubbedStatusCode = 500

        await sut.performEventRequest(eventName, sessionID: sessionID)

        XCTAssertNotNil(StubURLProtocol.lastRequest)
    }

    // MARK: - sendAnalyticsEvent

    func test_sendAnalyticsEvent_dispatchesNetworkRequestInBackground() async {
        StubURLProtocol.stubbedStatusCode = 200
        let expectation = expectation(description: "Stub received the analytics request")
        StubURLProtocol.onRequest = { _ in expectation.fulfill() }

        sut.sendAnalyticsEvent(eventName, sessionID: sessionID)

        await fulfillment(of: [expectation], timeout: 10.0)
        XCTAssertEqual(StubURLProtocol.lastRequest?.url, analyticsURL)
    }
}
