#import "POPViewController.h"
#import <WebKit/WebKit.h>
#import <PopupBridge/POPUserContentController.h>
#import <PopupBridge/POPPopupBridge.h>

@interface POPViewController () <POPViewControllerPresentingDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@end

@implementation POPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 1. Create Popup Bridge.
    POPPopupBridge *popupBridge = [[POPPopupBridge alloc] initWithDelegate:self];

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];

    // 2. Set your WKWebViewConfiguration's userContentController. If you already have a userContentController, you can subclass POPUserContentController instead.
    configuration.userContentController = popupBridge.userContentController;

    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) configuration:configuration];
    [self.view addSubview:self.webView];

    // 3. Set your WKWebView's navigationDelegate.
    self.webView.navigationDelegate = popupBridge.navigationDelegate;
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:3099"]]];
}

// 4. Implement -controller:shouldPresentURL: to filter the URLs that are presented in a Safari View Controller.
- (BOOL)controller:(WKUserContentController *)controller shouldPresentURL:(NSURL *)url {
    // Show an activity indicator instead of the PayPal landing frame
    if ([url.absoluteString hasSuffix:@"/html/paypal-landing-frame.html"]) {
        if (self.activityIndicatorView) [self.activityIndicatorView removeFromSuperview];
        self.activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        self.activityIndicatorView.frame = CGRectMake(10, 10, 310, 310);
        [self.activityIndicatorView startAnimating];
        [self.view addSubview:self.activityIndicatorView];
        return NO;
    }
    [self.activityIndicatorView removeFromSuperview];
    self.activityIndicatorView = nil;
    return YES;
}

- (void)controller:(WKUserContentController *)controller requestsPresentationOfViewController:(UIViewController *)viewController {
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)controller:(WKUserContentController *)controller requestsDismissalOfViewController:(UIViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

@end
