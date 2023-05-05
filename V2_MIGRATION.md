# PopupBridge iOS v2 Migration Guide

See the [CHANGELOG](/CHANGELOG.md) for a complete list of changes. This migration guide outlines the basics for updating your client integration from v1 to v2.

## Supported Versions

v2 supports a minimum deployment target of iOS 14+. It requires Xcode 14.1+ and Swift 5.7+. If your application contains Objective-C code, the `Enable Modules` build setting must be set to `YES`.

## Code Changes

The `POPPopupBridge.set(returnURLScheme:)` static method was removed. You no longer need to call this in your app delegate. 

Instead, `urlScheme` is now a required parameter to initialize a `POPPopupBridge` instance.

For example:
```swift
let popupBridge = POPPopupBridge(
    webView: webView,
    urlScheme: "com.your-company.your-app.popupbridge",
    delegate: self
)
```
