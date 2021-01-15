PopupBridge iOS
===============

[![Build Status](https://travis-ci.com/braintree/popup-bridge-ios.svg?branch=master)](https://travis-ci.com/braintree/popup-bridge-ios)

PopupBridge is an iOS library that allows WKWebViews to open popup windows in an SFSafariViewController browser and send data back to the parent page in the WKWebView.

PopupBridge is also available for [Android](https://github.com/braintree/popup-bridge-android).

See the [Frequently Asked Questions](#frequently-asked-questions) to learn more about PopupBridge. See [Using PayPal in a WebView](#using-paypal-in-a-webview) to use PopupBridge with PayPal.

Requirements
------------

- iOS 9.0+

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
    - Under **URL Schemes**, enter a unique URL scheme, e.g. `com.my-app.popupbridge`

1. In your application delegate's `didFinishLaunchingWithOptions` method, set the return URL scheme.

    ```objectivec
    #import "POPPopupBridge.h"

    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
    {
        [POPPopupBridge setReturnURLScheme:@"com.my-app.popupbridge"];
        return YES;
    }
    ```
    
    1. Inspect the return URL and then call `PopupBridge:openURL` from either your app delegate or your scene delegate.
     
     If you're using `UISceneDelegate` (introduced in iOS 13), call `PopupBridge:openURL` from within the  `scene:openURLContexts` delegate method. Pass the URL on the appropriate `UIOpenURLContext`. 
     
     ```objectivec
     - (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts {
        for (UIOpenURLContext *urlContext in URLContexts) {
            NSURL *url = [urlContext URL];
            if ([url.scheme localizedCaseInsensitiveCompare:@"com.my-app.popupbridge"] == NSOrderedSame) {
            [POPPopupBridge openURL:urlContext.URL];
            }
        }
    }
    ```
    
    If you aren't using `UISceneDelegate`, call `PopupBridge:openURL` from within the  `application:openURL:` delegate method of your app delegate.
    
    ```objectivec
    - (BOOL)application:(UIApplication *)app
                openURL:(NSURL *)url
                options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
        if ([url.scheme localizedCaseInsensitiveCompare:@"com.my-app.popupbridge"] == NSOrderedSame) {
            return [POPPopupBridge openURL:url];
        }
        return NO;
    }
    ```

1. Integrate PopupBridge with the WKWebView:

    ```objectivec
    #import "POPPopupBridge.h"

    @interface MyViewController () <POPPopupBridgeDelegate>
    @property (nonatomic, strong) WKWebView *webView;
    @property (nonatomic, strong) POPPopupBridge *popupBridge;
    @end

    @implementation MyViewController

    - (void)viewDidLoad
    {
        [super viewDidLoad];

        self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        [self.view addSubview:self.webView];

        self.popupBridge = [[POPPopupBridge alloc] initWithWebView:self.webView delegate:self];

        // replace http://localhost:3099/ with the webpage you want to open in the webview
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:3099/"]]];
    }

    - (void)popupBridge:(POPPopupBridge *)bridge requestsPresentationOfViewController:(UIViewController *)viewController {
        [self presentViewController:viewController animated:YES completion:nil];
    }

    - (void)popupBridge:(POPPopupBridge *)bridge requestsDismissalOfViewController:(UIViewController *)viewController {
      [viewController dismissViewControllerAnimated:YES completion:nil];
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
    - To help detect fraudulent activity, collect device data before performing PayPal transactions. This is similar to collecting device data with our [native iOS SDK](https://developers.braintreepayments.com/guides/paypal/vault/ios/v4) with a few differences:
        1. Rather than importing the entire data collector, you can add just PayPalDataCollector to your app: `pod 'Braintree/PayPalDataCollector'`
        1. Implement methods in your native app depending on whether you are doing one-time payments or vaulted payments. See the [iOS code snippets for PayPal + PopupBridge](popupbridge-paypaldatacollector-ios.md)
1. Profit!

Using PopupBridge to pass messages to a WebView
-----------------------------------------------

Although PopupBridge's primary purpose is to handle popups, it can be used in a more general use case to send URLs from the app to the JavaScript context in the WebView. These URLs can contain arbitrary data.

1. Register a URL type for your app, as described in the Quick Start.
1. In your application delegate, set up PopupBridge with the URL scheme:

    ```objectivec
    #import "POPPopupBridge.h"

    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
    {
        [POPPopupBridge setReturnURLScheme:@"com.my-app.popupbridge"];
        return YES;
    }
    ```

1. Add a handler to the `onComplete` callback:

   ```javascript
    if (window.popupBridge) {
      popupBridge.onComplete = function (err, payload) {
        if (err) {
          console.error('PopupBridge onComplete Error:', err);
          return;
        }

        console.log("Payload path:", payload.path);
        console.log("Payload query items:", payload.queryItems);
        console.log("Payload fragment:", payload.hash);
      };
    }
   ```

1. Create a URL that begins with your app's URL scheme and has a path of `popupbridgev1`, e.g. `com.my-app.popupbridge://popupbridgev1`. Add any additional data in the form of URL paths, query items, and fragments.
1. Call the PopupBridge `openUrl:options:` method with that URL. The `onComplete` handler will receive the URL as the payload. For example, if the URL is `com.my-app.popupbridge://popupbridgev1/hi/there?foo=bar#baz=qux`:
   ```javascript
   console.log("Payload path:", payload.path); // "/hi/there"
   console.log("Payload query items:", payload.queryItems); // {foo: "bar"}
   console.log("Payload fragment:", payload.hash); // "baz=qux"
   ```

## Author

Braintree, code@getbraintree.com

## License

    PopupBridge is available under the MIT license. See the LICENSE file for more info.


[bundler]: https://bundler.io/
[cocoapods]: https://cocoapods.org
[xcpretty]: https://github.com/xcpretty/xcpretty
