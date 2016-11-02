#import <Foundation/Foundation.h>

#import <WebKit/WebKit.h>

@protocol POPViewControllerPresentingDelegate <NSObject>
- (void)controller:(WKUserContentController * _Nonnull)controller requestsPresentationOfViewController:(UIViewController * _Nonnull)viewController;
- (void)controller:(WKUserContentController * _Nonnull)controller requestsDismissalOfViewController:(UIViewController * _Nonnull)viewController;
@end

@interface POPPopupBridge : NSObject

- (id)initWithDelegate:(id<POPViewControllerPresentingDelegate>)delegate scheme:(NSString *)scheme;

+ (BOOL)openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication;

@property (nonnull, nonatomic, readonly) WKUserContentController *userContentController;
@property (nonnull, nonatomic, readonly) id <WKNavigationDelegate> navigationDelegate;

@end
