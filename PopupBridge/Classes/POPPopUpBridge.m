#import "POPPopUpBridge.h"
#import "POPUserContentController.h"
#import "POPWebViewNavigation.h"

static void (^returnBlock)(NSURL *url);

@interface POPPopupBridge () <WKNavigationDelegate>

@property (nonnull, nonatomic, readwrite) NSString *scheme;
@property (nonnull, nonatomic, readwrite) WKUserContentController *userContentController;
@property (nonnull, nonatomic, readwrite) id <WKNavigationDelegate> navigationDelegate;

@property (nonnull, nonatomic) WKWebView *webView;
@end

@implementation POPPopupBridge

- (id)initWithDelegate:(id<POPViewControllerPresentingDelegate>)delegate scheme:(NSString *)scheme {
    if ( self = [super init] ) {
//        self.delegate = delegate;
//        self.userContentController = [[POPUserContentController alloc] initWithDelegate: delgate];
//        self.webViewNavigation = [[POPWebViewNavigation alloc] init];
//
//        [self.userContentController addScriptMessageHandler:self name:@"open"];

        self.scheme = scheme;
        self.userContentController = [[POPUserContentController alloc] initWithDelegate:delegate];
        self.navigationDelegate = self;

        __weak POPPopupBridge *weakSelf = self;
        returnBlock = ^(NSURL *url) {
            NSLog(@"%@", url);

            [(POPUserContentController *)weakSelf.userContentController dismissSafariViewController];

            NSLog(@"%@", url.query);

            NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url
                                                        resolvingAgainstBaseURL:NO];
            NSArray *queryItems = urlComponents.queryItems;

            NSMutableString *json = [@"{" mutableCopy];
            for (NSURLQueryItem *item in queryItems) {
                [json appendFormat:@"\"%@\": \"%@\",", item.name, item.value];
            }
            [json deleteCharactersInRange:NSMakeRange(json.length-1, 1)];
            [json appendString:@"}"];

            [weakSelf.webView evaluateJavaScript:[NSString stringWithFormat:@"PopupBridge.onClose(null, %@);", json] completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                NSLog(@"%@ %@", result, error);
            }];
        };
    }
    return self;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(__unused WKNavigation *)navigation {
    self.webView = webView;

    NSError *error;

    // TODO: maybe just have this be a string

    // maybe not [NSBundle mainBundle]
    NSString *path = [[NSBundle mainBundle] pathForResource:@"PopupBridge" ofType:@"js"];

    // TODO: Allow/require developer to set the scheme
    NSString *javascriptTemplate = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];

    if (error) {
        NSLog(@"Error: %@", error);
        return;
    }

    NSString *javascript = [[javascriptTemplate stringByReplacingOccurrencesOfString:@"%%SCHEME%%" withString:self.scheme] stringByReplacingOccurrencesOfString:@"%%VERSION%%" withString:@"v1"];

    [webView evaluateJavaScript:javascript completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSLog(@"Done! %@ %@", result, error);
    }];
}

+ (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
    if (returnBlock) {
        returnBlock(url);
    }
}

@end
