# PopupBridge iOS Release Notes

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
