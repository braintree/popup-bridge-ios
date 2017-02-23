#import "POPViewController.h"
#import <WebKit/WebKit.h>
#import <PopupBridge/POPPopupBridge.h>

@interface POPViewController () <POPPopupBridgeDelegate>
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
    self.popupBridge = [[POPPopupBridge alloc] initWithWebView:self.webView delegate:self];

    [self.view addSubview:self.webView];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://braintree.github.io/popup-bridge-example/"]]];
}

- (void)popupBridge:(POPPopupBridge *)bridge requestsPresentationOfViewController:(UIViewController *)viewController {
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)popupBridge:(POPPopupBridge *)bridge requestsDismissalOfViewController:(UIViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

@end
