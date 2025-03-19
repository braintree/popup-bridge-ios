import PopupBridge
import UIKit
import WebKit

final class PopupBridgeViewController: UIViewController {

    private let  buttonAdd: UIButton = {
        let button = UIButton()
        button.setTitle("Add", for: UIControl.State())
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    private let  buttonRemove: UIButton = {
        let button = UIButton()
        button.setTitle("Remove", for: UIControl.State())
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    private let customView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var webView: WKWebView?
    private var popupBridge: POPPopupBridge?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        buttonAdd.addTarget(self, action: #selector(createPopupBridge), for: .touchUpInside)
        buttonRemove.addTarget(self, action: #selector(deletePopupBridge), for: .touchUpInside)
        
        view.addSubview(buttonAdd)
        view.addSubview(buttonRemove)
        view.addSubview(customView)
        
        NSLayoutConstraint.activate([
            buttonAdd.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            buttonAdd.leftAnchor.constraint(equalTo: view.leftAnchor),
            buttonAdd.rightAnchor.constraint(equalTo: view.rightAnchor),
            buttonAdd.heightAnchor.constraint(equalToConstant: 100),
            
            buttonRemove.topAnchor.constraint(equalTo: buttonAdd.bottomAnchor),
            buttonRemove.leftAnchor.constraint(equalTo: view.leftAnchor),
            buttonRemove.rightAnchor.constraint(equalTo: view.rightAnchor),
            buttonRemove.heightAnchor.constraint(equalToConstant: 100),
            
            customView.topAnchor.constraint(equalTo: buttonRemove.bottomAnchor),
            customView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            customView.leftAnchor.constraint(equalTo: view.leftAnchor),
            customView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
    }

    @objc func createPopupBridge() {
        webView = WKWebView()
        setupConstraints()
        popupBridge = POPPopupBridge(webView: webView!)
        webView?.load(URLRequest(url: URL(string: "https://braintree.github.io/popup-bridge-example/")!))
    }
    
    @objc func deletePopupBridge() {
        popupBridge = nil
        webView?.removeFromSuperview()
        webView = nil
    }
    
    private func setupConstraints() {
        customView.addSubview(webView!)
        webView?.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            webView!.topAnchor.constraint(equalTo: customView.topAnchor),
            webView!.bottomAnchor.constraint(equalTo: customView.bottomAnchor),
            webView!.leadingAnchor.constraint(equalTo: customView.leadingAnchor),
            webView!.trailingAnchor.constraint(equalTo: customView.trailingAnchor)
        ])
    }
}
