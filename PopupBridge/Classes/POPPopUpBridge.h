#import <Foundation/Foundation.h>

#import <WebKit/WebKit.h>

@protocol POPViewControllerPresentingDelegate <NSObject>

/// Called when a URL needs to be presented.
///
/// @return YES if the URL should be presented.
///         NO otherwise.
- (BOOL)controller:(WKUserContentController * _Nonnull)controller shouldPresentURL:(NSURL * _Nonnull)url;

- (void)controller:(WKUserContentController * _Nonnull)controller requestsPresentationOfViewController:(UIViewController * _Nonnull)viewController;
- (void)controller:(WKUserContentController * _Nonnull)controller requestsDismissalOfViewController:(UIViewController * _Nonnull)viewController;
@end

@interface POPPopupBridge : NSObject

- (id _Nullable)initWithDelegate:(id<POPViewControllerPresentingDelegate> _Nonnull)delegate;

+ (void)setReturnURLScheme:(NSString * _Nonnull)returnURLScheme;
+ (BOOL)openURL:(NSURL * _Nonnull)url sourceApplication:(NSString * _Nullable)sourceApplication;

@property (nonnull, nonatomic, readonly) WKUserContentController *userContentController;
@property (nonnull, nonatomic, readonly) id <WKNavigationDelegate> navigationDelegate;

@end
