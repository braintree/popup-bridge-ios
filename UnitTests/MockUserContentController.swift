import Foundation
import WebKit

class MockUserContentController: WKUserContentController {

    // MARK: - Properties

    var scriptMessageHandler: Any?
    var name: String?

    // MARK: - Methods

    override func add(_ scriptMessageHandler: WKScriptMessageHandler, name: String) {
        self.scriptMessageHandler = scriptMessageHandler
        self.name = name
    }
}
