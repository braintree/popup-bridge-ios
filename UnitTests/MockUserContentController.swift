import Foundation
import WebKit

class MockUserContentController: WKUserContentController {

    // MARK: - Properties

    var scriptMessageHandler: Any?
    var name: String?

    // MARK: - Methods

    func addScriptMessageHandler(scriptMessageHandler: Any, name: String) {
        self.scriptMessageHandler = scriptMessageHandler
        self.name = name
    }
}
