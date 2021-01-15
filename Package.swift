// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "PopupBridge",
    platforms: [.iOS(.v9)],
    products: [
        .library(
            name: "PopupBridge",
            targets: ["PopupBridge"]
        ),
    ],
    targets: [
        .target(
            name: "PopupBridge",
            exclude: ["PopupBridge-Framework-Info.plist"],
            publicHeadersPath: "Public"
        ),
    ]
)
