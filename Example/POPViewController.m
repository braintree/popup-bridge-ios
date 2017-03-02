#import "POPViewController.h"
#import <WebKit/WebKit.h>
#import <PopupBridge/POPPopupBridge.h>
#import "PayPalDataCollector.h"

@interface POPViewController () <POPPopupBridgeDelegate, WKNavigationDelegate>
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
    
    self.webView.navigationDelegate = self;
    
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:3000"]]];
}

// Allow invalid SSL certificates. ** WARNING: DO NOT USE IN PRODUCTION CODE **
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    NSURLCredential * credential = [[NSURLCredential alloc] initWithTrust:[challenge protectionSpace].serverTrust];
    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
}

- (void)popupBridge:(POPPopupBridge *)bridge requestsPresentationOfViewController:(UIViewController *)viewController {
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)popupBridge:(POPPopupBridge *)bridge requestsDismissalOfViewController:(UIViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)popupBridge:(POPPopupBridge *)bridge willOpenURL:(NSURL *)url {
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name IN %@", @[@"token", @"ba_token"]];
    NSURLQueryItem *queryItem = [[components.queryItems filteredArrayUsingPredicate:predicate] firstObject];
    NSString *ecToken = queryItem.value;
    
    // Call PayPal Data Collector with ecToken as the client metadata ID
    NSString *result = [PPDataCollector clientMetadataID:ecToken];
    NSLog(@"Called PPDataCollector clientMetadataID:%@ and got %@", ecToken, result);
}

- (void)popupBridge:(POPPopupBridge *)bridge receivedMessage:(NSString *)messageName data:(NSString *)data {
    if ([messageName isEqualToString:@"requestDeviceData"]) {
        NSString *deviceData = [PPDataCollector collectPayPalDeviceData];
        [self.webView evaluateJavaScript:[NSString stringWithFormat:@"window.setDeviceData(%@);", deviceData] completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error: Unable to set device data. Details: %@", error.description);
            }
        }];
    }
}

@end
