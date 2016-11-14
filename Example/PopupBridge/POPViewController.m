#import "POPViewController.h"
#import <WebKit/WebKit.h>
#import <PopupBridge/POPPopupBridge.h>

@interface POPViewController () <POPViewControllerPresentingDelegate, WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) POPPopupBridge *popupBridge;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@end

@implementation POPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];

    // 2. Create Popup Bridge.
    self.popupBridge = [[POPPopupBridge alloc] initWithDelegate:self webView:self.webView];

    [self.view addSubview:self.webView];
    self.webView.navigationDelegate = self;
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:3099"]]];
}

- (void)popupBridge:(POPPopupBridge *)bridge requestsPresentationOfViewController:(UIViewController *)viewController {
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)popupBridge:(POPPopupBridge *)bridge requestsDismissalOfViewController:(UIViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    // 3. Enable PopupBridge for the page in the web view.
    // We recommend doing this in -webView:didCommitNavigation:
    [self.popupBridge enablePageInWebView:webView];
}

@end
