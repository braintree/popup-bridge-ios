#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#define kScriptMessageHandlerName @"POPPopupBridge"

NS_ASSUME_NONNULL_BEGIN

@class POPPopupBridge;

/// Popup Bridge will provide a Safari View Controller to your delegate.
/// You must present and dismiss the view controller in these delegate methods.
@protocol POPViewControllerPresentingDelegate <NSObject>
- (void)popupBridge:(POPPopupBridge *)bridge requestsPresentationOfViewController:(UIViewController *)viewController;
- (void)popupBridge:(POPPopupBridge *)bridge requestsDismissalOfViewController:(UIViewController *)viewController;
@end

/// Popup Bridge provides an alternative to window.open that works in WKWebView.
/// Pages will be opened in Safari View Controllers.
@interface POPPopupBridge : NSObject

/// Initialize Popup Bridge.
///
/// @param delegate A delegate that presents and dismisses the Safari View Controllers.
/// @param webView The web view to add a script message handler to. Do not change the web view's configuration or user content controller after initializing Popup Bridge.
- (instancetype)initWithDelegate:(id <POPViewControllerPresentingDelegate>)delegate webView:(WKWebView *)webView;

/// Enable Popup Bridge for a page.
/// You may wish to call this in your -webView:didFinishNavigation: delegate method.
///
/// @param webView The web view displaying the page that will use Popup Bridge.
- (void)enablePageInWebView:(WKWebView *)webView;

/// Set the URL Scheme that you have registered in your Info.plist.
+ (void)setReturnURLScheme:(NSString *)returnURLScheme;

/// Handle completion of the popup flow by calling this method from your
/// -application:openURL:sourceApplication:annotation: app delegate method.
+ (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication;

/// Use this as your WKWebViewConfiguration's userContentController.
@property (nonatomic, readonly) WKUserContentController *userContentController;

/// Use this as your WKWebView's navigationDelegate.
@property (nonatomic, readonly) id <WKNavigationDelegate> navigationDelegate;

@end

NS_ASSUME_NONNULL_END
