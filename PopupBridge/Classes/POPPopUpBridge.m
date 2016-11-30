#import "POPPopUpBridge.h"
#import <SafariServices/SFSafariViewController.h>

@interface POPPopupBridge () <WKNavigationDelegate, SFSafariViewControllerDelegate>
@property (nonatomic, readwrite, weak) id <POPViewControllerPresentingDelegate> viewControllerPresentingDelegate;
@property (nonnull, nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) SFSafariViewController *safariViewController;
@end

@implementation POPPopupBridge

static BOOL (^returnBlock)(NSURL *url);
static NSString *scheme;
NSString * const kPOPScriptMessageHandlerName = @"POPPopupBridge";
NSString * const kPOPURLHost = @"popupbridgev1";

+ (void)setReturnURLScheme:(NSString *)returnURLScheme {
    scheme = returnURLScheme;
}

- (id)initWithWebView:(WKWebView *)webView delegate:(id<POPViewControllerPresentingDelegate>)delegate {
    if (self = [super init]) {
        self.viewControllerPresentingDelegate = delegate;
        self.webView = webView;

        [webView.configuration.userContentController addScriptMessageHandler:self name:kPOPScriptMessageHandlerName];

        NSString *javascript = [[[[self javascriptTemplate] stringByReplacingOccurrencesOfString:@"%%SCHEME%%" withString:scheme]  stringByReplacingOccurrencesOfString:@"%%SCRIPT_MESSAGE_HANDLER_NAME%%" withString:kPOPScriptMessageHandlerName] stringByReplacingOccurrencesOfString:@"%%HOST%%" withString:kPOPURLHost];
        WKUserScript *script = [[WKUserScript alloc] initWithSource:javascript injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
        [webView.configuration.userContentController addUserScript:script];
    }
    return self;
}

- (NSString *)javascriptTemplate {
    // NB: This string does not maintain newlines, so you cannot use single-line JS comments.
    return @"\
        ;(function () {\
            if (!window.PopupBridge) { window.PopupBridge = {}; };\
            \
            window.PopupBridge.getReturnUrlPrefix = function getReturnUrlPrefix() {\
                return '%%SCHEME%%://%%HOST%%/';\
            };\
            \
            window.PopupBridge.open = function open(url) {\
                window.webkit.messageHandlers.%%SCRIPT_MESSAGE_HANDLER_NAME%%.postMessage({\
                    url: url\
                });\
            };\
            \
            return 0;\
        })();";
}

#pragma mark - SFSafariViewControllerDelegate

// User clicked "Done"
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    if (returnBlock) {
        returnBlock(nil);
        returnBlock = nil;
    }
}

+ (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
    if (returnBlock) {
        BOOL result = returnBlock(url);
        returnBlock = nil;
        return result;
    }
    return NO;
}

+ (BOOL)openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    if (returnBlock) {
        BOOL result = returnBlock(url);
        returnBlock = nil;
        return result;
    }
    return NO;
}

- (void)dismissSafariViewController {
    if (self.safariViewController) {
        if ([self.viewControllerPresentingDelegate respondsToSelector:@selector(popupBridge:requestsDismissalOfViewController:)]) {
            [self.viewControllerPresentingDelegate popupBridge:self requestsDismissalOfViewController:self.safariViewController];
        }
        self.safariViewController = nil;
    }
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:kPOPScriptMessageHandlerName]) {
        NSDictionary *params = message.body;
        NSString *urlString = params[@"url"];
        if (urlString) {
            [self dismissSafariViewController];

            __weak POPPopupBridge *weakSelf = self;
            returnBlock = ^(NSURL *url) {
                NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
                NSString *path = urlComponents.path;

                if (!([urlComponents.scheme isEqualToString:scheme] && [urlComponents.host isEqualToString:kPOPURLHost])) {
                    return NO;
                }

                [weakSelf dismissSafariViewController];

                NSString *err = @"null";
                NSString *payload = @"null";

                if (url) {
                    NSMutableDictionary *payloadDictionary = [[self.class dictionaryForQueryString:url.query] mutableCopy];
                    payloadDictionary[@"path"] = path;

                    NSError *error;
                    NSData *queryItemsData = [NSJSONSerialization dataWithJSONObject:payloadDictionary options:0 error:&error];
                    if (!queryItemsData) {
                        NSString *errorMessage = [NSString stringWithFormat:@"Failed to parse query items from return URL. %@", error.localizedDescription];
                        err = [NSString stringWithFormat:@"new Error(\"%@\")", errorMessage];
                    } else {
                        payload = [[NSString alloc] initWithData:queryItemsData encoding:NSUTF8StringEncoding];
                    }
                }

                [weakSelf.webView evaluateJavaScript:[NSString stringWithFormat:@"PopupBridge.onComplete(%@, %@);", err, payload] completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                    if (error) {
                        NSLog(@"Error: PopupBridge requires onComplete callback. Details: %@", error.description);
                    }
                }];

                return YES;
            };

            self.safariViewController = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:urlString]];
            self.safariViewController.delegate = self;
            if ([self.viewControllerPresentingDelegate respondsToSelector:@selector(popupBridge:requestsPresentationOfViewController:)]) {
                [self.viewControllerPresentingDelegate popupBridge:self requestsPresentationOfViewController:self.safariViewController];
            }
        }
    }
}

#pragma mark - Helpers

+ (NSDictionary *)dictionaryForQueryString:(NSString *)queryString {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    NSArray *components = [queryString componentsSeparatedByString:@"&"];
    for (NSString *keyValueString in components) {
        if ([keyValueString length] == 0) {
            continue;
        }

        NSArray *keyValueArray = [keyValueString componentsSeparatedByString:@"="];
        NSString *key = [self percentDecodedStringForString:keyValueArray[0]];
        if (!key) {
            continue;
        }
        if (keyValueArray.count == 2) {
            NSString *value = [self percentDecodedStringForString:keyValueArray[1]];
            parameters[key] = value;
        } else {
            parameters[key] = [NSNull null];
        }
    }
    return [NSDictionary dictionaryWithDictionary:parameters];
}

+ (NSString *)percentDecodedStringForString:(NSString *)string {
    return [[string stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByRemovingPercentEncoding];
}

@end
