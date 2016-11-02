#import <WebKit/WebKit.h>

@protocol POPViewControllerPresentingDelegate;

@interface POPUserContentController : WKUserContentController

- (id)initWithDelegate:(id<POPViewControllerPresentingDelegate>)delegate;

// TODO: maybe hide this in an internal header?
- (void)dismissSafariViewController;

@end
