PopupBridge iOS
===============

![GitHub Actions Tests](https://github.com/braintree/popup-bridge-ios/workflows/Tests/badge.svg)

PopupBridge is an iOS library that allows WKWebViews to open popup windows in an SFSafariViewController browser and send data back to the parent page in the WKWebView.

PopupBridge is also available for [Android](https://github.com/braintree/popup-bridge-android).

See the [Frequently Asked Questions](#frequently-asked-questions) to learn more about PopupBridge. See [Using PayPal in a WebView](#using-paypal-in-a-webview) to use PopupBridge with PayPal.

Requirements
------------

- iOS 14.0+
- Xcode 14.3+
- Swift 5.8+, or Objective-C

Installation
------------

### CocoaPods

To integrate using [CocoaPods](https://cocoapods.org), add the following line to your Podfile:

```ruby
pod 'PopupBridge'
```
### Carthage

To integrate using Carthage, add `github "braintree/popup-bridge-ios"` to your `Cartfile`, and [add the frameworks to your project](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application).

### Swift Package Manager

To integrate using Swift Package Manager, select File > Swift Packages > Add Package Dependency and enter `https://github.com/braintree/popup-bridge-ios` as the repository URL. Tick the checkbox for `PopupBridge`.

If you look at your app target, you will see that `PopupBridge` is automatically linked as a framework to your app (see General > Frameworks, Libraries, and Embedded Content).

Sample App
-------

To run the sample app, clone the repo, open `PopupBridge.xcworkspace` and run the `Demo` app target.

Quick Start
-----------

1. Register a URL type for your app:
    - In Xcode, click on your project in the Project Navigator and navigate to **App Target** > **Info** > **URL Types**
    - Click **[+]** to add a new URL type
    - Under **URL Schemes**, enter a unique URL scheme, e.g. `com.your-company.your-app`

    This scheme must start with your app's Bundle ID and be dedicated to PopupBridge app switch returns. For example, if the app bundle ID is `com.your-company.your-app`, then your URL scheme could be `com.your-company.your-app.popupbridge`.
    
1. Inspect the return URL and then call `PopupBridge.open(url:)` from either your app delegate or your scene delegate.

    If you're using `UISceneDelegate` (introduced in iOS 13), call `POPPopupBridge.open(url:)` from within the `scene(_:openURLContexts:)` scene delegate method.

    ```swift
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        URLContexts.forEach { context in
            if context.url.scheme?.localizedCaseInsensitiveCompare("com.your-company.your-app.popupbridge") == .orderedSame {
                POPPopupBridge.open(url: context.url)
            }
        }
    }
    ```

    If you aren't using `UISceneDelegate`, call `PopupBridge.open(url:)` from within the  `application(_:open:options:)` delegate method of your app delegate.

    ```swift
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme?.localizedCaseInsensitiveCompare("com.your-company.your-app.popupbridge") == .orderedSame {
            return POPPopupBridge.open(url: url)
        }
        return false
    }
    ```

1. Integrate PopupBridge with your WKWebView:

    ```swift
    class ViewController: UIViewController {
        
        var webView: WKWebView = WKWebView(frame: CGRect(x: 0, y: 0, width: 300, height: 700))
        var popupBridge: POPPopupBridge?

        override func viewDidLoad() {
            super.viewDidLoad()

            view.addSubview(webView)
            
            popupBridge = POPPopupBridge(
                webView: webView,
                urlScheme: "com.your-company.your-app.popupbridge",
                delegate: self
            )
            
            // Replace http://localhost:3099/ with the webpage you want to open in the webview
            let url = URL(string: "http://localhost:3099/")!
            webView.load(URLRequest(url: url))
        }
    }

    extension ViewController: POPPopupBridgeDelegate{
        
        func popupBridge(_ bridge: PopupBridge.POPPopupBridge, requestsDismissalOfViewController viewController: UIViewController) {
            viewController.dismiss(animated: true)
        }
        
        func popupBridge(_ bridge: PopupBridge.POPPopupBridge, requestsPresentationOfViewController viewController: UIViewController) {
            present(viewController, animated: true)
        }
    }
    ```

1. Use PopupBridge from the web page by writing some JavaScript:

    ```javascript
    var url = 'http://localhost:3099/popup'; // or whatever the page is that you want to open in a popup

    if (window.popupBridge) {
      // Open the popup in a browser, and give it the deep link back to the app
      popupBridge.open(url + '?popupBridgeReturnUrlPrefix=' + popupBridge.getReturnUrlPrefix());

      // Optional: define a callback to process results of interaction with the popup
      popupBridge.onComplete = function (err, payload) {
        if (err) {
          console.error('PopupBridge onComplete Error:', err);
        } else if (!err && !payload) {
          console.log('User closed popup.');
        } else {
          alert('Your favorite color is ' + payload.queryItems.color);
        }
      };
    } else {
      var popup = window.open(url);

      window.addEventListener('message', function (event) {
        var color = JSON.parse(event.data).color;

        if (color) {
          popup.close();
          alert('Your favorite color is ' + color);
        }
      });
    }
    ```

1. Redirect back to the app inside of the popup:

    ```html
    <h1>What is your favorite color?</h1>

    <a href="#red" data-color="red">Red</a>
    <a href="#green" data-color="green">Green</a>
    <a href="#blue" data-color="blue">Blue</a>

    <script src="jquery.js"></script>
    <script>
    $('a').on('click', function (event) {
      var color = $(this).data('color');

      if (location.search.indexOf('popupBridgeReturnUrlPrefix') !== -1) {
        var prefix = location.search.split('popupBridgeReturnUrlPrefix=')[1];
        // Open the deep link back to the app, and send some data
        location.href = prefix + '?color=' + color;
      } else {
        window.opener.postMessage(JSON.stringify({ color: color }), '*');
      }
    });
    </script>
    ```

Frequently Asked Questions
--------------------------

### Why use PopupBridge?

WKWebView can open popups through its [`WKUIDelegate`](https://developer.apple.com/reference/webkit/wkuidelegate), which can be implemented to present the popup in a new WKWebView.

However, WKWebViews do not display an address bar or an HTTPS lock icon. If the popup receives sensitive user information (e.g. login credentials), users must implicitly trust that the web page is not redirecting them to a malicious spoofed page that may steal their information. PopupBridge solves this by using an SFSafariViewController.

### What are some use cases for using PopupBridge?

- Apps with WebViews that need to open a popup
- When a popup window needs to to send data from the popup back to the WKWebView
- When the popup window needs to display the HTTPS lock icon to increase user trust
- Apps that use OAuth

### How does it work?

- PopupBridge attaches to a WKWebView by [injecting a user script](https://developer.apple.com/reference/webkit/wkusercontentcontroller/1537448-adduserscript) to the page
  - This exposes a JavaScript interface (via `window.popupBridge`) for the web page to interact with the iOS code
- The web page detects whether the page has access to `window.popupBridge`; if so, it uses `popupBridge.open` to open the popup URL
  - `popupBridge.open` creates a SFSafariViewController to open the popup URL and has its delegate present the view controller
  - The web page can also use `popupBridge.onComplete` as a callback
- The popup web page uses a deep link URL to dismiss the popup
  - The deep link URL should match a deep link URL type in Xcode
  - The app delegate handles the deep link URL and forwards it to PopupBridge
  - One way to avoid hard-coding the deep link is by adding it as a query parameter to the popup URL:

    ```javascript
      popupBridge.open(url + '?popupBridgeReturnUrlPrefix=' + popupBridge.getReturnUrlPrefix());
    ```

    - Optionally, you can add path components and query parameters to the deep link URL to return data to the parent page, which are provided in the payload of `popupBridge.onComplete` 
- If the user taps the **Done** button on the SFSafariViewController, `popupBridge.onComplete` gets called with the error and payload as `null` and the delegate dismisses the view controller

### Who built PopupBridge?

We are engineers who work on the Developer Experience team at [Braintree](https://www.braintreepayments.com).

### Why did Braintree build PopupBridge?

Short answer: to accept PayPal as a payment option when mobile apps are using a WebView to power the checkout process.

PayPal authentication occurs in a popup window. However, this causes issues with Braintree merchants who use a web page to power payments within their apps: they can't accept PayPal because WebViews cannot open popups and return the PayPal payment authorization data to the parent checkout page.

PopupBridge solves this problem by allowing [`braintree-web`](https://github.com/braintree/braintree-web) or [PayPal's Checkout.js](https://github.com/paypal/paypal-checkout) to open the PayPal popup from a secure mini-browser.

Using PayPal in a WebView
-------------------------

WebView-based checkout flows can accept PayPal with PopupBridge and the [Braintree JS SDK](https://github.com/braintree/braintree-web) or [PayPal's Checkout.js](https://github.com/paypal/paypal-checkout). For the authentication flow, PayPal requires a popup window—which can be simulated with PopupBridge.

### Setup
1. Create a web-based checkout that accepts PayPal using Checkout.js or the Braintree JS SDK
1. Create a native mobile app that opens the checkout in a `WKWebView` (See steps 1-3 of the quick start instructions)
1. Integrate the PopupBridge library
1. Collect device data
    - To help detect fraudulent activity, collect device data before performing PayPal transactions. This is similar to collecting device data with our [native iOS SDK](https://developer.paypal.com/braintree/docs/guides/paypal/vault/ios/v5) with a few differences:
        1. Rather than importing the entire data collector, you can add just PayPalDataCollector to your app: `pod 'Braintree/PayPalDataCollector'`
        1. Implement methods in your native app depending on whether you are doing one-time payments or vaulted payments. See the [iOS code snippets for PayPal + PopupBridge](popupbridge-paypaldatacollector-ios.md)
1. Profit!

## Versions

This SDK abides by our Client SDK Deprecation Policy. For more information on the potential statuses of an SDK check our [developer docs](https://developer.paypal.com/braintree/docs/guides/client-sdk/deprecation-policy/ios/v5).

| Major version number | Status | Released | Deprecated | Unsupported |
| -------------------- | ------ | -------- | ---------- | ----------- |
| 1.x.x | Active | 2016 | TBA | TBA |

## Author

Braintree, code@getbraintree.com

## License

    PopupBridge is available under the MIT license. See the LICENSE file for more info.
