#import "POPUserContentController.h"

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <SafariServices/SFSafariViewController.h>
#import "POPPopupBridge.h"

@interface POPUserContentController () <WKScriptMessageHandler>
@property (nonatomic, weak) id<POPViewControllerPresentingDelegate> delegate;
@property (nonatomic, strong) SFSafariViewController *safariViewController;
@end

@implementation POPUserContentController

- (id)initWithDelegate:(id<POPViewControllerPresentingDelegate>)delegate {
    if ( self = [super init] ) {
        self.delegate = delegate;

        [self addScriptMessageHandler:self name:@"PopupBridge"];
    }
    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    NSDictionary *params = message.body;
    NSString *urlString = params[@"URL"];
    NSLog(@"urlString = %@", urlString);

    // TODO: grab some JSONP-like function name from the url and call it in appSwitchReturnBlock

    if (urlString) {
        [self dismissSafariViewController];
        self.safariViewController = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:urlString]];
        [self.delegate controller:self requestsPresentationOfViewController:self.safariViewController];
    }
}

- (void)dismissSafariViewController {
    if (self.safariViewController) {
        [self.delegate controller:self requestsDismissalOfViewController:self.safariViewController];
    }
}

@end
