import Foundation

enum NetworkError: Error {
    case invalidResponse
    case encodingError(Error)
}
