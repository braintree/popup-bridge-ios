import Foundation
import XCTest

extension XCTestCase {
    
    func assertMemoryLeak(instance: AnyObject, file: StaticString, line: UInt) {
        XCTAssertNil(instance, "Expected \(String(describing: instance)) to be deallocated. Potential memory leak!", file: file, line: line)
    }
}
