// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PopupBridge",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "PopupBridge",
            targets: ["PopupBridge"]
        ),
    ],
    targets: [
        .target(
            name: "PopupBridge",
            exclude: ["PopupBridge-Framework-Info.plist"]
        ),
    ]
)
