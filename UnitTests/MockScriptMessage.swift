import Foundation
import WebKit

class MockScriptMessage: WKScriptMessage {

    private var _body: Any?
    private var _name: String?

    override var body: Any {
        get {
            return _body ?? ""
        } set {
            _body = newValue
        }
    }

    override var name: String {
        get {
            return _name ?? ""
        } set {
            _name = newValue
        }
    }
}
