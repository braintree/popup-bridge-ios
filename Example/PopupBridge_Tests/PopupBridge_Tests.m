#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "POPPopupBridge.h"

@interface PopupBridge_Tests : XCTestCase

@end

@implementation PopupBridge_Tests

- (void)testInit_addsUserScript {
    WKWebView *webView = [[WKWebView alloc] init];
    id<POPViewControllerPresentingDelegate> delegate = (id<POPViewControllerPresentingDelegate>)[[NSObject alloc] init];

    XCTAssertEqual(webView.configuration.userContentController.userScripts.count, 0);

    __unused POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:delegate];

    XCTAssertEqual(webView.configuration.userContentController.userScripts.count, 1);
    WKUserScript *userScript = webView.configuration.userContentController.userScripts[0];
    XCTAssertEqual(userScript.injectionTime, WKUserScriptInjectionTimeAtDocumentStart);
    XCTAssertTrue(userScript.forMainFrameOnly);
}

- (void)testInit_addsScriptMessageHandler {
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    id mockUserContentController = OCMClassMock([WKUserContentController class]);
    configuration.userContentController = mockUserContentController;
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    id<POPViewControllerPresentingDelegate> delegate = (id<POPViewControllerPresentingDelegate>)[[NSObject alloc] init];

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:delegate];

    OCMVerify([mockUserContentController addScriptMessageHandler:(id<WKScriptMessageHandler>)pub name:kScriptMessageHandlerName]);
}

@end
