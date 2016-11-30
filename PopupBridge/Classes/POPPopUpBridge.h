#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kPOPScriptMessageHandlerName;
extern NSString * const kPOPURLHost;

@class POPPopupBridge;

/// Popup Bridge will provide a Safari View Controller to your delegate.
/// You must present and dismiss the view controller in these delegate methods.
@protocol POPViewControllerPresentingDelegate <NSObject>
@required
- (void)popupBridge:(POPPopupBridge *)bridge requestsPresentationOfViewController:(UIViewController *)viewController;
- (void)popupBridge:(POPPopupBridge *)bridge requestsDismissalOfViewController:(UIViewController *)viewController;
@end

/// Popup Bridge provides an alternative to window.open that works in WKWebView.
/// Pages will be opened in Safari View Controllers.
@interface POPPopupBridge : NSObject <WKScriptMessageHandler>

/// Initialize Popup Bridge.
///
/// @param webView The web view to add a script message handler to. Do not change the web view's configuration or user content controller after initializing Popup Bridge.
/// @param delegate A delegate that presents and dismisses the Safari View Controllers.
- (id)initWithWebView:(WKWebView *)webView delegate:(id<POPViewControllerPresentingDelegate>)delegate;

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
