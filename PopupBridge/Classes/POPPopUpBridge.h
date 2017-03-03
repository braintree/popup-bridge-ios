#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kPOPScriptMessageHandlerName;
extern NSString * const kPOPURLHost;

@class POPPopupBridge;

/// Set a delegate to handle various events the "popup" lifecycle.
@protocol POPPopupBridgeDelegate <NSObject>
@required

/// Popup Bridge will provide a Safari View Controller to your delegate.
/// You must present the view controller in this method.
- (void)popupBridge:(POPPopupBridge *)bridge requestsPresentationOfViewController:(UIViewController *)viewController;

/// You must dismiss the view controller in this method.
- (void)popupBridge:(POPPopupBridge *)bridge requestsDismissalOfViewController:(UIViewController *)viewController;

@optional

/// Optional: Receive the URL that will be opened
- (void)popupBridge:(POPPopupBridge *)bridge willOpenURL:(NSURL *)url;

/// Optional: Receive messages from the web view
- (void)popupBridge:(POPPopupBridge *)bridge receivedMessage:(NSString *)messageName data:(nullable NSString *)data;
@end

/// Popup Bridge provides an alternative to window.open that works in WKWebView.
/// Pages will be opened in Safari View Controllers.
@interface POPPopupBridge : NSObject <WKScriptMessageHandler>

/// Initialize Popup Bridge.
///
/// @param webView The web view to add a script message handler to. Do not change the web view's configuration or user content controller after initializing Popup Bridge.
/// @param delegate A delegate that presents and dismisses the Safari View Controllers.
- (id)initWithWebView:(WKWebView *)webView delegate:(id<POPPopupBridgeDelegate>)delegate;

/// @brief Send a message with optional data to the JavaScript context in the web view.
///
/// The web page can receive this message by setting `window.popupBridge.bridgeToWeb` to a custom function:
///
/// @code
/// // JavaScript
/// window.popupBridge.bridgeToWeb = function (messageName, data) {
///   console.log('My native app sent me message ' + messageName + ' with data: ' + data);
/// };
///
/// // iOS
/// [popupBridge bridgeToWeb:@"messageName" data:"This is my data" completionHandler:nil];
/// // In the webview console: "My native app sent me message messageName with data: This is my data"
/// @endcode
///
/// @param messageName The name of the message
/// @param data An optional string payload to send with the message. This can be used to send JSON strings that are parsed and deserialized by the web page.
/// @param completionHandler An optional completion handler that executes when the message has been sent. It returns the return value or an error.
- (void)bridgeToWeb:(NSString *)messageName
               data:(nullable NSString *)data
  completionHandler:(void (^ _Nullable)(id _Nullable returnValue, NSError * _Nullable error))completionHandler;

/// Set the URL Scheme that you have registered in your Info.plist.
+ (void)setReturnURLScheme:(NSString *)returnURLScheme;

/// Handle completion of the popup flow by calling this method from your
/// -application:openURL:sourceApplication:annotation: app delegate method.
/// Required by iOS 8.
+ (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication;

/// Handle completion of the popup flow by calling this method from your
/// -application:openURL:sourceApplication:annotation: app delegate method.
/// Used by iOS 9+.
+ (BOOL)openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options;

@end

NS_ASSUME_NONNULL_END
