#import "POPPopUpBridge.h"
#import <SafariServices/SFSafariViewController.h>

@interface POPPopupBridge () <WKNavigationDelegate, SFSafariViewControllerDelegate, WKScriptMessageHandler>
@property (nonnull, nonatomic, readwrite) id <POPViewControllerPresentingDelegate> viewControllerPresentingDelegate;
@property (nonnull, nonatomic) WKWebView *webView;
@property (nonatomic, strong) SFSafariViewController *safariViewController;
@end

@implementation POPPopupBridge

static void (^returnBlock)(NSURL *url);
static NSString *scheme;

+ (void)setReturnURLScheme:(NSString *)returnURLScheme {
    scheme = returnURLScheme;
}

- (id)initWithDelegate:(id<POPViewControllerPresentingDelegate>)delegate webView:(WKWebView *)webView {
    if ( self = [super init] ) {
        self.viewControllerPresentingDelegate = delegate;
        self.webView = webView;

        [webView.configuration.userContentController addScriptMessageHandler:self name:kScriptMessageHandlerName];

        __weak POPPopupBridge *weakSelf = self;
        returnBlock = ^(NSURL *url) {
            [weakSelf dismissSafariViewController];
            NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url
                                                        resolvingAgainstBaseURL:NO];
            NSArray *queryItems = urlComponents.queryItems;
            NSMutableString *json = [@"{" mutableCopy];
            if (queryItems.count >= 1) {
                for (NSURLQueryItem *item in queryItems) {
                    [json appendFormat:@"\"%@\": \"%@\",", item.name, item.value];
                }
                [json deleteCharactersInRange:NSMakeRange(json.length-1, 1)];
            }
            [json appendString:@"}"];

            NSString *err = @"null";
            NSString *payload = @"null";
            if ([url.path hasSuffix:@"return"]) {
                payload = json;
            } else {
                err = [NSString stringWithFormat:@"{ \"path\": \"%@\", \"payload\": %@ }", url.path, json];
            }
            [weakSelf.webView evaluateJavaScript:[NSString stringWithFormat:@"window.PopupBridge.onCompleteCallback(%@, %@);", err, payload] completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"Error: PopupBridge requires onCompleteCallback. Details: %@", error.description);
                }
            }];
        };
    }
    return self;
}

- (void)enablePageInWebView:(WKWebView *)webView {
    NSString *javascript = [[[[self javascriptTemplate] stringByReplacingOccurrencesOfString:@"%%SCHEME%%" withString:scheme] stringByReplacingOccurrencesOfString:@"%%VERSION%%" withString:@"v1"] stringByReplacingOccurrencesOfString:@"%%SCRIPT_MESSAGE_HANDLER_NAME%%" withString:kScriptMessageHandlerName];

    [webView evaluateJavaScript:javascript completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        if (![result isEqual:@0]) {
            if (error) {
                NSLog(@"Error creating PopupBridge: %@", error);
            } else {
                NSLog(@"Unknown error creating PopupBridge");
            }
        }
    }];
}

#pragma mark - SFSafariViewControllerDelegate

// User clicked "Done"
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    NSURL *url = [NSURL URLWithString:@""];
    if (returnBlock) {
        returnBlock(url);
    }
}

+ (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
    if (returnBlock) {
        returnBlock(url);
    }
}

- (NSString *)javascriptTemplate {
    return @"\
        (function(){\
            if (!window.PopupBridge) {\
                window.PopupBridge = {\
                    scheme: '%%SCHEME%%://popupbridge/%%VERSION%%/',\
                    open: function (URL,name,specs) {\
                        window.webkit.messageHandlers.%%SCRIPT_MESSAGE_HANDLER_NAME%%.postMessage({URL: URL,name: name,specs: specs});\
                    }\
                };\
            };\
            return 0;\
        })();";
}

- (void)dismissSafariViewController {
    if (self.safariViewController) {
        [self.viewControllerPresentingDelegate popupBridge:self requestsDismissalOfViewController:self.safariViewController];
    }
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:kScriptMessageHandlerName]) {
        NSDictionary *params = message.body;
        NSString *urlString = params[@"URL"];
        if (urlString) {
            [self dismissSafariViewController];
            self.safariViewController = nil;

            NSURL *url = [NSURL URLWithString:urlString];
            self.safariViewController = [[SFSafariViewController alloc] initWithURL:url];
            self.safariViewController.delegate = self;
            [self.viewControllerPresentingDelegate popupBridge:self requestsPresentationOfViewController:self.safariViewController];
        }
    }
}

@end
