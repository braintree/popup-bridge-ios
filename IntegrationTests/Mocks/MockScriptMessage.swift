import WebKit

final class MockScriptMessage: WKScriptMessage {

    var stubName: String = ""
    var stubBody: Any = [:]

    override var name: String {
        get { stubName }
        set { stubName = newValue }
    }

    override var body: Any {
        get { stubBody }
        set { stubBody = newValue }
    }
}
