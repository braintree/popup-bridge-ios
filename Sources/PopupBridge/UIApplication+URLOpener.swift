import UIKit

protocol URLOpener {
    
    func isVenmoAppInstalled() -> Bool
}

extension UIApplication: URLOpener {
    
    /// Indicates whether the Venmo App is installed.
    func isVenmoAppInstalled() -> Bool {
        guard let venmoURL = URL(string: "com.venmo.touch.v2://") else {
            return false
        }
        return canOpenURL(venmoURL)
    }
}
