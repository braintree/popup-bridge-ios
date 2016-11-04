#import "POPUserContentController.h"

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <SafariServices/SFSafariViewController.h>
#import "POPPopupBridge.h"

@interface POPUserContentController () <WKScriptMessageHandler>
@property (nonatomic, weak) id<POPViewControllerPresentingDelegate> delegate;
@property (nonatomic, weak) id<SFSafariViewControllerDelegate> safariViewControllerDelegate;
@property (nonatomic, strong) SFSafariViewController *safariViewController;
@end

@implementation POPUserContentController

- (id)initWithDelegate:(id<POPViewControllerPresentingDelegate>)delegate safariViewControllerDelegate:(id<SFSafariViewControllerDelegate>)safariViewControllerDelegate {
    if ( self = [super init] ) {
        self.delegate = delegate;
        self.safariViewControllerDelegate = safariViewControllerDelegate;

        [self addScriptMessageHandler:self name:@"PopupBridge"];
    }
    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
//    NSLog(@"message.name = %@, message.body = %@", message.name, message.body);

    if ([message.name isEqualToString:@"PopupBridge"]) {
        NSDictionary *params = message.body;
        NSString *urlString = params[@"URL"];
//        NSLog(@"urlString = %@", urlString);

        // TODO: grab some JSONP-like function name from the url and call it in appSwitchReturnBlock

        if (urlString) {
            [self dismissSafariViewController];
            self.safariViewController = nil;

            NSURL *url = [NSURL URLWithString:urlString];

            NSLog(@"checking whether to present urlString = %@", urlString);
            if ([self.delegate controller:self shouldPresentURL:url]) {
                self.safariViewController = [[SFSafariViewController alloc] initWithURL:url];
                self.safariViewController.delegate = self.safariViewControllerDelegate;
                NSLog(@"presenting view controller = %@", self.safariViewController);
                [self.delegate controller:self requestsPresentationOfViewController:self.safariViewController];
            }
        }
    }
}

- (void)dismissSafariViewController {
    if (self.safariViewController) {
        [self.delegate controller:self requestsDismissalOfViewController:self.safariViewController];
    }
}

@end
