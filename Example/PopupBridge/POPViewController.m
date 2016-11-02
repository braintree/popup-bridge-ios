#import "POPViewController.h"
#import <WebKit/WebKit.h>
#import <PopupBridge/POPUserContentController.h>
#import <PopupBridge/POPPopupBridge.h>

@interface POPViewController () <POPViewControllerPresentingDelegate>
@property WKWebView *webView;
@end

@implementation POPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 1. Create Popup Bridge
    POPPopupBridge *popupBridge = [[POPPopupBridge alloc] initWithDelegate:self scheme:@"com.braintreepayments.popupbridgeexample"];

    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];

    // 2. Set your WKWebViewConfiguration's userContentController
    configuration.userContentController = popupBridge.userContentController;

    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) configuration:configuration];
    [self.view addSubview:self.webView];

    // 3. Set your WKWebView's navigationDelegate
    self.webView.navigationDelegate = popupBridge.navigationDelegate;
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:3099"]]];
}

- (void)controller:(WKUserContentController *)controller requestsPresentationOfViewController:(UIViewController *)viewController {
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)controller:(WKUserContentController *)controller requestsDismissalOfViewController:(UIViewController *)viewController {
    [viewController dismissViewControllerAnimated:NO completion:nil];
}

@end
