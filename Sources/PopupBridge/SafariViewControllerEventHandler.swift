import SafariServices

/// An internal class used to obfuscate `SFSafariViewControllerDelegate` conformace from the merchant-facing `POPPopupBridge` API.
class SafariViewControllerEventHandler: NSObject, SFSafariViewControllerDelegate {
    
    private let didFinish: () -> Void
    
    /// Initialize a `SafariViewControllerEventHandler`.
    /// - Parameter callback: Code to be invoked when `safariViewControllerDidFinish` is called.
    init(didFinish callback: @escaping () -> Void) {
        self.didFinish = callback
    }
    
    // MARK: - SFSafariViewControllerDelegate
    
    /// The user dismissed the SFSafariViewController by clicking "Done".
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        didFinish()
    }
}
