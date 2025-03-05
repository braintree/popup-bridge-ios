@testable import PopupBridge
import XCTest

class NetworkClient_Tests: XCTestCase {

    var sut: NetworkClient!
    var mockSession: MockSession!
    
    let body = FPTIBatchData(
        metadata: .init(sessionID: "some-session-id"),
        events: [.init(eventName: "some-event-name")]
    )
    
    override func setUp() {
        super.setUp()
        mockSession = MockSession()
        sut = NetworkClient(session: mockSession)
    }
    
    override func tearDown() {
        sut = nil
        mockSession = nil
        super.tearDown()
    }
    
    func testPost_success() async throws {
        let url = URL(string: "https://example.com/api/post")!
        let expectedData = Data("success response".utf8)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        
        mockSession.mockData = expectedData
        mockSession.mockResponse = response
        
        do {
            try await sut.post(url: url, body: body)
        } catch {
            XCTFail("Post should succeed but failed with error: \(error)")
        }
    }
    
    func testPost_failureWithInvalidResponse() async throws {
        let url = URL(string: "https://example.com/api/post")!
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        
        mockSession.mockData = Data()
        mockSession.mockResponse = response
        
        do {
            try await sut.post(url: url, body: body)
            XCTFail("Post should have failed due to invalid HTTP response status")
        } catch NetworkError.invalidResponse {
            XCTAssert(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
