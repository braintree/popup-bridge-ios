# PopupBridge iOS Release Notes

## unreleased

* Add optional `enablePopupBridgeAppSwitch` flag to `POPPopupBridge` initializer. When enabled, the SDK attempts to launch the native PayPal app for checkout instead of opening a browser session. Falls back to `ASWebAuthenticationSession` if the app launch fails.
  * **Action required:** when `enablePopupBridgeAppSwitch: true` is set, the host app must implement `scene(_:openURLContexts:)` in its `SceneDelegate` and post a `NotificationCenter` notification named `PopupBridgeConstants.notificationName` with the return URL. Without this hook, the checkout flow will hang after the PayPal app returns. See the README for the required code snippet.
* Expose `isPayPalInstalled`, `launchApp()`, and `getDeepLinkReturnUrlPrefix()` on `window.popupBridge` in JavaScript.
* Add optional `returnURLScheme` parameter to `POPPopupBridge` initializer. Allows integrators with multiple URL schemes registered in `Info.plist` (e.g. Facebook, Google Sign-In) to explicitly specify which scheme PopupBridge should use as the return URL, avoiding ambiguity in the automatic `CFBundleURLTypes` lookup.

## 3.0.0 (2025-04-01)
* Breaking Changes
  * Bump minimum supported deployment target to iOS 16+
  * Require Xcode 16.2.0+ and Swift 5.10+
* Add the `prefersEphemeralWebBrowserSession` property to the `POPPopupBridge` initializer, which specifies whether to request a private authentication session from the browser.
* Add validation to check if the Venmo app is installed on the device.

## 2.2.0  (2025-02-05)
* Require Xcode 15.0+ and Swift 5.9+ (per [App Store requirements](https://developer.apple.com/news/?id=khzvxn8a))

## 2.1.0 (2024-03-21)
* Inject popup bridge JS script code into all frames, versus just mainframe. Fixes bug where popup bridge couldn't launch from within an iFrame.
* Add blank privacy manifest file. [Meets Apple's new Privacy Update requirements](https://developer.apple.com/news/?id=3d8a9yyh)

## 2.0.0 (2023-10-18)

* **Note:** Includes all changes in [2.0.0-beta1](#200-beta1-2023-08-28)

## 2.0.0-beta1 (2023-08-28)

* Convert PopupBridge to Swift
* Breaking Changes
  * Require iOS 14+, Xcode 15.0+, and Swift 5.9+
  * Remove deprecated `POPPopupBridge.open(url:sourceApplication:)` & `POPPopupBridge.open(url:options:)` methods
  * Remove `POPPopupBridge.set(returnURLScheme:)`
  * Remove `open(url:)`
  * Replace `SFSafariViewController` with `ASWebAuthenticationSession`
  * No longer need to register a URL type to use Popup Bridge
  * Removed `POPPopupBridgeDelegate`
  * The initializer for `POPPopupBridge` now only requires a `WKWebView` `POPPopupBridge(webView:)`

## 1.2.0 (2021-01-22)

* Exclude arm64 simulator architectures via Podspec
* Add Swift Package Manager support (resolves #27)

## 1.1.0 (2020-05-13)

* Add `PopupBridge:openURL` method
* Deprecate `PopupBridge:openURL:options` and `PopupBridge:openURL:sourceApplication`
* Update README to include `SceneDelegate` usage instructions
* Fix a bug that prevented returning from the pop-up more than once

## 1.0.0 (2019-01-31)

* If page has created an `popupBridge.onCancel` function, it will be called when user closes the window

## 0.1.1 (2017-09-29)

* Fix reference cycle caused by script message handler being retained

## 0.1.0 (2017-02-23)

* Initial release of PopupBridge iOS
* Questions or feedback? Create an issue on GitHub :)
