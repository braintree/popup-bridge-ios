import Foundation

final class StubURLProtocol: URLProtocol {

    static var stubbedStatusCode: Int = 200
    static var lastRequest: URLRequest?
    static var onRequest: ((URLRequest) -> Void)?

    static func reset() {
        stubbedStatusCode = 200
        lastRequest = nil
        onRequest = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var capturedRequest = request
        if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
            var data = Data()
            stream.open()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(buffer, maxLength: 4096)
                if count > 0 { data.append(buffer, count: count) }
            }
            buffer.deallocate()
            stream.close()
            capturedRequest.httpBody = data
        }
        Self.lastRequest = capturedRequest
        Self.onRequest?(capturedRequest)
        guard let url = request.url,
              let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: Self.stubbedStatusCode,
                httpVersion: nil,
                headerFields: nil
              ) else { return }
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
