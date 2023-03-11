import SafariServices

class SafariHelper: NSObject, SFSafariViewControllerDelegate {
    
    private let callback: () -> Void
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
    }
    
    // MARK: - SFSafariViewControllerDelegate
    
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        callback()
    }
}
