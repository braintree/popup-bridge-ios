# PopupBridge iOS v2 Migration Guide

See the [CHANGELOG](/CHANGELOG.md) for a complete list of changes. This migration guide outlines the basics for updating your client integration from v1 to v2.

## Supported Versions

v2 supports a minimum deployment target of iOS 14+. It requires Xcode 14.3+ and Swift 5.8+. If your application contains Objective-C code, the `Enable Modules` build setting must be set to `YES`.

## Code Changes

The `POPPopupBridge.set(returnURLScheme:)` and `open(url:)` static methods were removed. You no longer need to call the `POPPopupBridge.set(returnURLScheme:)` method in your app delegate.

You no longer need to register a URL type in your `Info.plist` to use Popup Bridge. Additionally, `POPPopupBridgeDelegate` has been removed.

The initializer for `POPPopupBridge` now only requires a `WKWebView`.

For example:
```swift
let popupBridge = POPPopupBridge(webView: webView)
```
