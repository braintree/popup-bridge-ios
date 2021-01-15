#import "POPPopupBridge.h"
#import "POPWeakScriptMessageDelegate.h"
#import <SafariServices/SFSafariViewController.h>

@interface POPPopupBridge () <SFSafariViewControllerDelegate>
@property (nonatomic, readwrite, weak) id <POPPopupBridgeDelegate> delegate;
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

- (id)initWithWebView:(WKWebView *)webView delegate:(id<POPPopupBridgeDelegate>)delegate {
    if (!scheme) {
        [NSException raise:@"POPPopupBridgeSchemeNotSet" format:@"PopupBridge requires a URL scheme to be set"];
        return nil;
    }
    if (self = [super init]) {
        self.delegate = delegate;
        self.webView = webView;

        // Use POPWeakScriptMessageDelegate to prevent a reference cycle where userContentController
        // maintains a reference to this instance.
        [webView.configuration.userContentController addScriptMessageHandler:[[POPWeakScriptMessageDelegate alloc] initWithDelegate:self] name:kPOPScriptMessageHandlerName];

        NSString *javascript = [[[[self javascriptTemplate] stringByReplacingOccurrencesOfString:@"%%SCHEME%%" withString:scheme]  stringByReplacingOccurrencesOfString:@"%%SCRIPT_MESSAGE_HANDLER_NAME%%" withString:kPOPScriptMessageHandlerName] stringByReplacingOccurrencesOfString:@"%%HOST%%" withString:kPOPURLHost];
        WKUserScript *script = [[WKUserScript alloc] initWithSource:javascript injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
        [webView.configuration.userContentController addUserScript:script];

        __weak POPPopupBridge *weakSelf = self;
        returnBlock = ^(NSURL *url) {
            NSString *err = @"null";
            NSString *payload = @"null";
            NSString *script;

            if (url) {
                NSURLComponents *urlComponents = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
                NSString *path = urlComponents.path;

                if ([urlComponents.scheme localizedCaseInsensitiveCompare:scheme] != NSOrderedSame ||
                    [urlComponents.host localizedCaseInsensitiveCompare:kPOPURLHost] != NSOrderedSame) {
                    return NO;
                }

                [weakSelf dismissSafariViewController];

                NSMutableDictionary *payloadDictionary = [NSMutableDictionary new];
                payloadDictionary[@"path"] = path;
                payloadDictionary[@"queryItems"] = [weakSelf.class dictionaryForQueryString:url.query];
                if (url.fragment) {
                    payloadDictionary[@"hash"] = url.fragment;
                }

                NSError *error;
                NSData *payloadData = [NSJSONSerialization dataWithJSONObject:payloadDictionary options:0 error:&error];
                if (!payloadData) {
                    NSString *errorMessage = [NSString stringWithFormat:@"Failed to parse query items from return URL. %@", error.localizedDescription];
                    err = [NSString stringWithFormat:@"new Error(\"%@\")", errorMessage];
                } else {
                    payload = [[NSString alloc] initWithData:payloadData encoding:NSUTF8StringEncoding];
                }
                script = [NSString stringWithFormat:@"window.popupBridge.onComplete(%@, %@);", err, payload];
            } else {
                script = @""
                "if (typeof window.popupBridge.onCancel === 'function') {"
                "  window.popupBridge.onCancel();"
                "} else {"
                "  window.popupBridge.onComplete(null, null);"
                "}";
            }

            [weakSelf.class injectWebView:weakSelf.webView withJavaScript:script];

            return YES;
        };
    }
    return self;
}

- (NSString *)javascriptTemplate {
    // NB: This string does not maintain newlines, so you cannot use single-line JS comments.
    return @"\
        ;(function () {\
            if (!window.popupBridge) { window.popupBridge = {}; };\
            \
            window.popupBridge.getReturnUrlPrefix = function getReturnUrlPrefix() {\
                return '%%SCHEME%%://%%HOST%%/';\
            };\
            \
            window.popupBridge.open = function open(url) {\
                window.webkit.messageHandlers.%%SCRIPT_MESSAGE_HANDLER_NAME%%.postMessage({\
                    url: url\
                });\
            };\
            \
            window.popupBridge.sendMessage = function sendMessage(message, data) {\
                window.webkit.messageHandlers.%%SCRIPT_MESSAGE_HANDLER_NAME%%.postMessage({\
                    message: {\
                        name: message,\
                        data: data\
                    }\
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
    }
}

+ (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
    return [POPPopupBridge openURL:url];
}

+ (BOOL)openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    return [POPPopupBridge openURL:url];
}

+ (BOOL)openURL:(NSURL *)url {
    if (returnBlock) {
        return returnBlock(url);
    }
    return NO;
}

- (void)dismissSafariViewController {
    if (self.safariViewController) {
        if ([self.delegate respondsToSelector:@selector(popupBridge:requestsDismissalOfViewController:)]) {
            [self.delegate popupBridge:self requestsDismissalOfViewController:self.safariViewController];
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

            NSURL *url = [NSURL URLWithString:urlString];
            
            if ([self.delegate respondsToSelector:@selector(popupBridge:willOpenURL:)]) {
                [self.delegate popupBridge:self willOpenURL:url];
            }
            
            self.safariViewController = [[SFSafariViewController alloc] initWithURL:url];
            self.safariViewController.delegate = self;
            if ([self.delegate respondsToSelector:@selector(popupBridge:requestsPresentationOfViewController:)]) {
                [self.delegate popupBridge:self requestsPresentationOfViewController:self.safariViewController];
            }
        } else if (params[@"message"][@"name"] && [self.delegate respondsToSelector:@selector(popupBridge:receivedMessage:data:)]) {
            [self.delegate popupBridge:self receivedMessage:params[@"message"][@"name"] data:params[@"message"][@"data"]];
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

+ (void)injectWebView:(WKWebView *)webView withJavaScript:(NSString *)script {
    [webView evaluateJavaScript:script completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error: PopupBridge requires onComplete callback. Details: %@", error.description);
        }
    }];
}

@end
