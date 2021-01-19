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

/// Set the URL Scheme that you have registered in your Info.plist.
+ (void)setReturnURLScheme:(NSString *)returnURLScheme;

/// Handle completion of the popup flow by calling this method from your
/// -application:openURL:sourceApplication:annotation: app delegate method.
/// Required by iOS 8.
+ (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication DEPRECATED_MSG_ATTRIBUTE("Use openURL: instead.");

/// Handle completion of the popup flow by calling this method from your
/// -application:openURL:sourceApplication:annotation: app delegate method.
/// Used by iOS 9+.
+ (BOOL)openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options DEPRECATED_MSG_ATTRIBUTE("Use openURL: instead.");

/// Handle completion of the popup flow by calling this method from either
/// your -scene:openURLContexts: scene delegate method or
/// your -application:openURL:sourceApplication:annotation: app delegate method.
+ (BOOL)openURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
