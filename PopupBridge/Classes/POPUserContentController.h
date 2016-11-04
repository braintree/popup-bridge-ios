#import <WebKit/WebKit.h>
#import <SafariServices/SFSafariViewController.h>

@protocol POPViewControllerPresentingDelegate;

@interface POPUserContentController : WKUserContentController

- (id)initWithDelegate:(id<POPViewControllerPresentingDelegate>)delegate safariViewControllerDelegate:(id<SFSafariViewControllerDelegate>)safariViewControllerDelegate;

// If your subclass overrides this method, you must call super.
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message;

// TODO: maybe hide this in an internal header?
- (void)dismissSafariViewController;

@end
