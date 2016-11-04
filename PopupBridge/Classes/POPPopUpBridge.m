#import "POPPopUpBridge.h"
#import "POPUserContentController.h"
#import "POPWebViewNavigation.h"

@interface POPPopupBridge () <WKNavigationDelegate, SFSafariViewControllerDelegate>
@property (nonnull, nonatomic, readwrite) WKUserContentController *userContentController;
@property (nonnull, nonatomic, readwrite) id <WKNavigationDelegate> navigationDelegate;

@property (nonnull, nonatomic) WKWebView *webView;
@end

@implementation POPPopupBridge

static void (^returnBlock)(NSURL *url);
static NSString *scheme;

+ (void)setReturnURLScheme:(NSString *)returnURLScheme {
    scheme = returnURLScheme;
}

- (id)initWithDelegate:(id<POPViewControllerPresentingDelegate>)delegate {
    if ( self = [super init] ) {
        self.userContentController = [[POPUserContentController alloc] initWithDelegate:delegate safariViewControllerDelegate:self];
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
            [weakSelf.webView evaluateJavaScript:[NSString stringWithFormat:@"PopupBridge.onCompleteCallback(%@, %@);", err, payload] completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                NSLog(@"%@ %@", result, error);
            }];
        };
    }
    return self;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(__unused WKNavigation *)navigation {
    self.webView = webView;

    NSString *javascriptTemplate = [self javascriptTemplate];

    NSString *javascript = [[javascriptTemplate stringByReplacingOccurrencesOfString:@"%%SCHEME%%" withString:scheme] stringByReplacingOccurrencesOfString:@"%%VERSION%%" withString:@"v1"];

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

#pragma SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    NSURL *url = [NSURL URLWithString:@""];
    [POPPopupBridge processResult:url];
}

+ (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
    [POPPopupBridge processResult:url];
}

+ (void)processResult:(NSURL *)url {
    if (returnBlock) {
        returnBlock(url);
    }
}

- (NSString *)javascriptTemplate {
    return @"\
    (function(){\
    window.PopupBridge = {\
    scheme: '%%SCHEME%%://popupbridge/%%VERSION%%/',\
    open: function (URL,name,specs) {\
        window.webkit.messageHandlers.PopupBridge.postMessage({URL: URL,name: name,specs: specs});\
        return new Proxy({\
        location: new Proxy({}, {\
        set: function(target, property, value, receiver) {\
            window.webkit.messageHandlers.PopupBridge.postMessage({property: property, URL: value});\
        }}),\
        }, {\
        set: function(target, property, value, receiver) {\
        }\
        });\
    }\
    }; return 0;})();\
    ";
}

@end
