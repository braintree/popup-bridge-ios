import UIKit

struct FPTIBatchData: Codable {
    
    let appID: String = Bundle.main.infoDictionary?[kCFBundleIdentifierKey as String] as? String ?? "N/A"
    
    let appName: String = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "N/A"
    
    let clientSDKVersion: String
    
    let clientOS: String = UIDevice.current.systemName + " " + UIDevice.current.systemVersion
    
    let component: String = "popupbridgesdk"
    
    let deviceManufacturer: String = "Apple"
    
    let deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }()
    
    let eventName: String
    
    let eventSource: String = "mobile-native"
    
    let isSimulator: Bool = {
        #if targetEnvironment(simulator)
            true
        #else
            false
        #endif
    }()
    
    let merchantAppVersion: String = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String ?? "N/A"
    
    let packageManager: String = {
        #if COCOAPODS
            "CocoaPods"
        #elseif SWIFT_PACKAGE
            "Swift Package Manager"
        #else
            "Carthage or Other"
        #endif
    }()
    
    let platform: String = "iOS"
    
    let sessionID: String
    
    let timestamp: String = String(Date().utcTimestampMilliseconds)
    
    let tenantName: String = "Braintree"
    
    enum CodingKeys: String, CodingKey {
        case appID = "app_id"
        case appName = "app_name"
        case clientSDKVersion = "c_sdk_ver"
        case clientOS = "client_os"
        case component = "comp"
        case deviceManufacturer = "device_manufacturer"
        case eventName = "event_name"
        case eventSource = "event_source"
        case packageManager = "ios_package_manager"
        case isSimulator = "is_simulator"
        case merchantAppVersion = "mapv"
        case deviceModel = "mobile_device_model"
        case platform
        case sessionID = "session_id"
        case timestamp = "t"
        case tenantName = "tenant_name"
    }
}
