#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "POPPopupBridge.h"
#import <SafariServices/SafariServices.h>

@interface PopupBridge_Tests : XCTestCase <WKNavigationDelegate>

@end

@implementation PopupBridge_Tests

static void (^webviewReadyBlock)();

- (void)setUp {
    [super setUp];

    [POPPopupBridge setReturnURLScheme:@"com.braintreepayments.popupbridgeexample"];
}

- (void)tearDown {
    webviewReadyBlock = nil;
}

- (void)testInit_addsUserScript {
    WKWebView *webView = [[WKWebView alloc] init];
    id<POPPopupBridgeDelegate> delegate = (id<POPPopupBridgeDelegate>)[[NSObject alloc] init];

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
    id<POPPopupBridgeDelegate> delegate = (id<POPPopupBridgeDelegate>)[[NSObject alloc] init];

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:delegate];

    OCMVerify([mockUserContentController addScriptMessageHandler:pub name:kPOPScriptMessageHandlerName]);
}

- (void)testInit_whenSchemeIsNotSet_throwsError {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [POPPopupBridge setReturnURLScheme:nil];
#pragma clang diagnostic pop
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero];

    NSException *thrownException;
    POPPopupBridge *popupBridge;
    @try {
        popupBridge = [[POPPopupBridge alloc] initWithWebView:webView delegate:(id<POPPopupBridgeDelegate>)[[NSObject alloc] init]];
    } @catch (NSException *exception) {
        thrownException = exception;
    } @finally {
        XCTAssertEqualObjects(thrownException.name, @"POPPopupBridgeSchemeNotSet");
        XCTAssertNil(popupBridge);
    }
}

- (void)testReceiveScriptMessage_whenMessageContainsURL_requestsPresentationOfSafariViewController {
    WKScriptMessage *stubMessage = OCMClassMock([WKScriptMessage class]);
    OCMStub(stubMessage.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(stubMessage.name).andReturn(kPOPScriptMessageHandlerName);
    WKWebView *stubWebView = OCMClassMock([WKWebView class]);
    OCMStub([stubWebView configuration]).andDo(nil);
    id mockDelegate = OCMProtocolMock(@protocol(POPPopupBridgeDelegate));

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:stubWebView delegate:mockDelegate];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:stubMessage];

    OCMVerify([mockDelegate popupBridge:pub requestsPresentationOfViewController:[OCMArg checkWithBlock:^BOOL(UIViewController *viewController) {
        return [viewController isKindOfClass:[SFSafariViewController class]];
    }]]);
}

- (void)testReceiveScriptMessage_whenMessageContainsURL_informsDelegateThatURLWillBeLoaded {
    WKScriptMessage *stubMessage = OCMClassMock([WKScriptMessage class]);
    OCMStub(stubMessage.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(stubMessage.name).andReturn(kPOPScriptMessageHandlerName);
    WKWebView *stubWebView = OCMClassMock([WKWebView class]);
    OCMStub([stubWebView configuration]).andDo(nil);
    id mockDelegate = OCMProtocolMock(@protocol(POPPopupBridgeDelegate));

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:stubWebView delegate:mockDelegate];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:stubMessage];

    OCMVerify([mockDelegate popupBridge:pub willOpenURL:[NSURL URLWithString:@"http://example.com/?hello=world"]]);
}

- (void)testReceiveScriptMessage_whenURLIsMissing_doesNotRequestPresentationOfViewControllers {
    WKScriptMessage *stubMessage = OCMClassMock([WKScriptMessage class]);
    OCMStub(stubMessage.body).andReturn(@{});
    OCMStub(stubMessage.name).andReturn(kPOPScriptMessageHandlerName);
    WKWebView *stubWebView = OCMClassMock([WKWebView class]);
    OCMStub([stubWebView configuration]).andDo(nil);
    id mockDelegate = OCMStrictProtocolMock(@protocol(POPPopupBridgeDelegate));

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:stubWebView delegate:mockDelegate];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:stubMessage];
}

- (void)testReceiveScriptMessage_whenMessageNameIsNotScriptMessageHandlerName_doesNotRequestPresentationOfViewControllers {
    WKScriptMessage *stubMessage = OCMClassMock([WKScriptMessage class]);
    OCMStub(stubMessage.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(stubMessage.name).andReturn(@"foo");
    WKWebView *stubWebView = OCMClassMock([WKWebView class]);
    OCMStub([stubWebView configuration]).andDo(nil);
    id mockDelegate = OCMStrictProtocolMock(@protocol(POPPopupBridgeDelegate));

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:stubWebView delegate:mockDelegate];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:stubMessage];
}


- (void)testPopupBridge_whenDoneButtonTappedOnSafariViewController_callsOnCompleteWithNoPayloadOrError {
    WKScriptMessage *message = OCMClassMock([WKScriptMessage class]);
    OCMStub(message.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(message.name).andReturn(kPOPScriptMessageHandlerName);
    WKWebView *webView = OCMClassMock([WKWebView class]);
    SFSafariViewController *stubSafari = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:@"http://example.com"]];

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:(id<POPPopupBridgeDelegate>)[[NSObject alloc] init]];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:message];

    [((id <SFSafariViewControllerDelegate>)pub) safariViewControllerDidFinish:stubSafari];

    OCMVerify([webView evaluateJavaScript:@"window.popupBridge.onComplete(null, null);" completionHandler:OCMOCK_ANY]);
}

- (void)testOpenURL_whenReturnURLHasQueryParams_passesPayloadWithQueryItemsToWebView {
    WKScriptMessage *message = OCMClassMock([WKScriptMessage class]);
    OCMStub(message.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(message.name).andReturn(kPOPScriptMessageHandlerName);
    WKWebView *webView = OCMClassMock([WKWebView class]);

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:(id<POPPopupBridgeDelegate>)[[NSObject alloc] init]];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:message];
    [POPPopupBridge openURL:[NSURL URLWithString:@"com.braintreepayments.popupbridgeexample://popupbridgev1/return?something=foo&other=bar"] options:@{}];

    OCMVerify([webView evaluateJavaScript:[OCMArg checkWithBlock:^BOOL(NSString *javascriptCommand) {
        NSString *payload = [[javascriptCommand stringByReplacingOccurrencesOfString:@"window.popupBridge.onComplete(null, " withString:@""] stringByReplacingOccurrencesOfString:@");" withString:@""];
        NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:[payload dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        XCTAssertEqualObjects(jsonDictionary[@"path"], @"/return");
        NSDictionary *queryItems = jsonDictionary[@"queryItems"];
        XCTAssertEqualObjects(queryItems[@"something"], @"foo");
        XCTAssertEqualObjects(queryItems[@"other"], @"bar");
        return YES;
    }] completionHandler:OCMOCK_ANY]);
}

- (void)testOpenURL_whenReturnURLHasNoQueryParams_passesPayloadWithNoQueryItemsToWebView {
    WKScriptMessage *message = OCMClassMock([WKScriptMessage class]);
    OCMStub(message.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(message.name).andReturn(kPOPScriptMessageHandlerName);
    WKWebView *webView = OCMClassMock([WKWebView class]);

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:(id<POPPopupBridgeDelegate>)[[NSObject alloc] init]];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:message];
    [POPPopupBridge openURL:[NSURL URLWithString:@"com.braintreepayments.popupbridgeexample://popupbridgev1/return"] options:@{}];

    OCMVerify([webView evaluateJavaScript:[OCMArg checkWithBlock:^BOOL(NSString *javascriptCommand) {
        NSString *payload = [[javascriptCommand stringByReplacingOccurrencesOfString:@"window.popupBridge.onComplete(null, " withString:@""] stringByReplacingOccurrencesOfString:@");" withString:@""];
        NSDictionary *jsonDictionary = [NSJSONSerialization JSONObjectWithData:[payload dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        XCTAssertEqualObjects(jsonDictionary[@"path"], @"/return");
        NSDictionary *queryItems = jsonDictionary[@"queryItems"];
        XCTAssertNotNil(queryItems);
        XCTAssertEqual(queryItems.count, 0);
        return YES;
    }] completionHandler:OCMOCK_ANY]);
}

- (void)testOpenURL_whenReturnURLDoesNotMatchScheme_returnsFalseAndDoesNotCallOnComplete {
    WKScriptMessage *message = OCMClassMock([WKScriptMessage class]);
    OCMStub(message.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(message.name).andReturn(kPOPScriptMessageHandlerName);
    // Use strict mock to verify that webview does not call onComplete
    WKWebView *webView = OCMStrictClassMock([WKWebView class]);
    OCMStub([webView configuration]).andReturn(nil);

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:(id<POPPopupBridgeDelegate>)[[NSObject alloc] init]];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:message];

    BOOL result = [POPPopupBridge openURL:[NSURL URLWithString:@"not.the.right.scheme://popupbridgev1/return?something=foo"] options:@{}];
    XCTAssertFalse(result);
}

- (void)testOpenURL_whenReturnURLDoesNotMatchHost_returnsFalseAndDoesNotCallOnComplete {
    WKScriptMessage *message = OCMClassMock([WKScriptMessage class]);
    OCMStub(message.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(message.name).andReturn(kPOPScriptMessageHandlerName);
    // Use strict mock to verify that webview does not call onComplete
    WKWebView *webView = OCMStrictClassMock([WKWebView class]);
    OCMStub([webView configuration]).andReturn(nil);

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:(id<POPPopupBridgeDelegate>)[[NSObject alloc] init]];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:message];

    BOOL result = [POPPopupBridge openURL:[NSURL URLWithString:@"com.braintreepayments.popupbridgeexample://notcorrect/return?something=foo"] options:@{}];
    XCTAssertFalse(result);
}

- (void)testDelegate_whenWebViewCallsPopupBridgeSendMessage_receivesMessage {
    id mockDelegate = OCMProtocolMock(@protocol(POPPopupBridgeDelegate));
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero];
    webView.navigationDelegate = self;
    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:mockDelegate];

    id expectation = [self expectationWithDescription:@"Called JS"];

    webviewReadyBlock = ^{
        [webView evaluateJavaScript:@"window.popupBridge.sendMessage('myMessageName', JSON.stringify({foo: 'bar'}));" completionHandler:^(__unused id _Nullable returnValue, __unused NSError * _Nullable error) {
            OCMVerify([mockDelegate popupBridge:pub receivedMessage:@"myMessageName" data:@"{\"foo\":\"bar\"}"]);
            [expectation fulfill];
        }];
    };

    [webView loadHTMLString:@"<html></html>" baseURL:nil];

    [self waitForExpectationsWithTimeout:1 handler:nil];
}

// Consider adding tests for query parameter parsing - multiple values, special characters, encoded, etc.

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (webviewReadyBlock) {
        webviewReadyBlock();
    }
}

@end
