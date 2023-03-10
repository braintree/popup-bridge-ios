#import "POPViewController.h"
#import <WebKit/WebKit.h>
#import <PopupBridge/PopupBridge-Swift.h>

@interface POPViewController () <POPPopupBridgeDelegateSwift>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) POPPopupBridgeSwift *popupBridge;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@end

@implementation POPViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];

    // 2. Create Popup Bridge.
    self.popupBridge = [[POPPopupBridgeSwift alloc] initWithWebView:self.webView delegate:self];

    [self.view addSubview:self.webView];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://braintree.github.io/popup-bridge-example/"]]];
}

- (void)popupBridge:(POPPopupBridgeSwift *)bridge requestsPresentationOfViewController:(UIViewController *)viewController {
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)popupBridge:(POPPopupBridgeSwift *)bridge requestsDismissalOfViewController:(UIViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

@end
