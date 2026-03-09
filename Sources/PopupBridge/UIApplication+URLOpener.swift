import UIKit

protocol URLOpener {

    func isVenmoAppInstalled() -> Bool
    func isPayPalAppInstalled() -> Bool
    func openURL(_ url: URL, completionHandler: @escaping (Bool) -> Void)
}

extension UIApplication: URLOpener {

    /// Indicates whether the Venmo App is installed.
    func isVenmoAppInstalled() -> Bool {
        guard let venmoURL = URL(string: "com.venmo.touch.v2://") else {
            return false
        }
        return canOpenURL(venmoURL)
    }

    /// Indicates whether the PayPal App is installed.
    func isPayPalAppInstalled() -> Bool {
        guard let paypalURL = URL(string: "paypal-app-switch-checkout://") else {
            return false
        }
        return canOpenURL(paypalURL)
    }

    func openURL(_ url: URL, completionHandler: @escaping (Bool) -> Void) {
        open(url, options: [:], completionHandler: completionHandler)
    }
}
