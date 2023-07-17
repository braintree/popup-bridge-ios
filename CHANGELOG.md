# PopupBridge iOS Release Notes

## unreleased

* Convert PopupBridge to Swift
* Breaking Changes
  * Require iOS 14+, Xcode 14.3+, and Swift 5.8+
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
