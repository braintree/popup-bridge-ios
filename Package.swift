// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PopupBridge",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "PopupBridge",
            targets: ["PopupBridge"]
        ),
    ],
    targets: [
        .target(
            name: "PopupBridge",
            path: "Sources/PopupBridge", 
            exclude: ["PopupBridge-Framework-Info.plist"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
    ]
)
