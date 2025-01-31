import PopupBridge
import UIKit
import WebKit

final class PopupBridgeViewController: UIViewController {
    
    // MARK: - Private Properties
    
    private let webView = WKWebView()
    
    private var popupBridge: POPPopupBridge?
    
    // MARK: - Internal Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupConstraints()
        popupBridge = POPPopupBridge(webView: webView)
        webView.load(URLRequest(url: URL(string: "https://braintree.github.io/popup-bridge-example/")!))
    }
    
    // MARK: - Private Methods
    
    private func setupConstraints() {
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}
