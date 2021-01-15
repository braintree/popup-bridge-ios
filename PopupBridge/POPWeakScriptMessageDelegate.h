///
/// From https://stackoverflow.com/a/33365424/766491
/// This wrapper class provides a weak reference to a WKScriptMessageHandler to prevent
/// reference cycles caused by WKUserContentController, which retains message handlers
/// by default.
///

@interface POPWeakScriptMessageDelegate : NSObject<WKScriptMessageHandler>

@property (nonatomic, weak) id<WKScriptMessageHandler> scriptDelegate;

- (instancetype)initWithDelegate:(id<WKScriptMessageHandler>)scriptDelegate;

@end
