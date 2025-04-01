import Foundation
import XCTest

extension XCTestCase {
    
    @discardableResult
    func trackForMemoryLeak<T: AnyObject & Sendable>(
        instance: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(
                instance,
                "Potential memory leak on \(String(describing: instance))",
                file: file,
                line: line
            )
        }
        return instance
    }
}
