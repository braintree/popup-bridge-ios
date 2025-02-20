import Foundation

extension Bundle {
    
    static var clientSDKVersion: String {
        Bundle(identifier: "com.braintreepayments.PopupBridge")?.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }
}
