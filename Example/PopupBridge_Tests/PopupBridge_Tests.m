#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "POPPopupBridge.h"
#import <SafariServices/SafariServices.h>

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

    OCMVerify([mockUserContentController addScriptMessageHandler:pub name:kPOPScriptMessageHandlerName]);
}

- (void)testReceiveScriptMessage_whenMessageContainsURL_requestsPresentationOfSafariViewController {
    WKScriptMessage *stubMessage = OCMClassMock([WKScriptMessage class]);
    OCMStub(stubMessage.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(stubMessage.name).andReturn(kPOPScriptMessageHandlerName);
    WKWebView *stubWebView = OCMClassMock([WKWebView class]);
    OCMStub([stubWebView configuration]).andDo(nil);
    id mockDelegate = OCMProtocolMock(@protocol(POPViewControllerPresentingDelegate));

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:stubWebView delegate:mockDelegate];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:stubMessage];

    OCMVerify([mockDelegate popupBridge:pub requestsPresentationOfViewController:[OCMArg checkWithBlock:^BOOL(UIViewController *viewController) {
        return [viewController isKindOfClass:[SFSafariViewController class]];
    }]]);
}

- (void)testReceiveScriptMessage_whenURLIsMissing_doesNotRequestPresentationOfViewControllers {
    WKScriptMessage *stubMessage = OCMClassMock([WKScriptMessage class]);
    OCMStub(stubMessage.body).andReturn(@{});
    OCMStub(stubMessage.name).andReturn(kPOPScriptMessageHandlerName);
    WKWebView *stubWebView = OCMClassMock([WKWebView class]);
    OCMStub([stubWebView configuration]).andDo(nil);
    id mockDelegate = OCMStrictProtocolMock(@protocol(POPViewControllerPresentingDelegate));

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:stubWebView delegate:mockDelegate];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:stubMessage];
}

- (void)testReceiveScriptMessage_whenMessageNameIsNotScriptMessageHandlerName_doesNotRequestPresentationOfViewControllers {
    WKScriptMessage *stubMessage = OCMClassMock([WKScriptMessage class]);
    OCMStub(stubMessage.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(stubMessage.name).andReturn(@"foo");
    WKWebView *stubWebView = OCMClassMock([WKWebView class]);
    OCMStub([stubWebView configuration]).andDo(nil);
    id mockDelegate = OCMStrictProtocolMock(@protocol(POPViewControllerPresentingDelegate));

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:stubWebView delegate:mockDelegate];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:stubMessage];
}

- (void)testReturnBlock_whenReturnURLHasQueryParams_passesPayloadWithQueryItemsToWebView {
    WKScriptMessage *message = OCMClassMock([WKScriptMessage class]);
    OCMStub(message.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(message.name).andReturn(kPOPScriptMessageHandlerName);
    WKWebView *webView = OCMClassMock([WKWebView class]);

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:(id<POPViewControllerPresentingDelegate>)[[NSObject alloc] init]];
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

- (void)testReturnBlock_whenReturnURLHasNoQueryParams_passesPayloadWithNoQueryItemsToWebView {
    WKScriptMessage *message = OCMClassMock([WKScriptMessage class]);
    OCMStub(message.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(message.name).andReturn(kPOPScriptMessageHandlerName);
    WKWebView *webView = OCMClassMock([WKWebView class]);

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:(id<POPViewControllerPresentingDelegate>)[[NSObject alloc] init]];
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

- (void)testReturnBlock_whenDoneButtonTappedOnSafariViewController_callsOnCompleteWithNoPayloadOrError {
    WKScriptMessage *message = OCMClassMock([WKScriptMessage class]);
    OCMStub(message.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(message.name).andReturn(kPOPScriptMessageHandlerName);
    WKWebView *webView = OCMClassMock([WKWebView class]);
    SFSafariViewController *stubSafari = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:@"http://example.com"]];

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:(id<POPViewControllerPresentingDelegate>)[[NSObject alloc] init]];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:message];

    [((id <SFSafariViewControllerDelegate>)pub) safariViewControllerDidFinish:stubSafari];

    OCMVerify([webView evaluateJavaScript:@"window.popupBridge.onComplete(null, null);" completionHandler:OCMOCK_ANY]);
}

- (void)testReturnBlock_whenReturnURLDoesNotMatchScheme_returnsFalseAndDoesNotCallOnComplete {
    WKScriptMessage *message = OCMClassMock([WKScriptMessage class]);
    OCMStub(message.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(message.name).andReturn(kPOPScriptMessageHandlerName);
    // Use strict mock to verify that webview does not call onComplete
    WKWebView *webView = OCMStrictClassMock([WKWebView class]);
    OCMStub([webView configuration]).andReturn(nil);

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:(id<POPViewControllerPresentingDelegate>)[[NSObject alloc] init]];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:message];

    BOOL result = [POPPopupBridge openURL:[NSURL URLWithString:@"not.the.right.scheme://popupbridgev1/return?something=foo"] options:@{}];
    XCTAssertFalse(result);
}

- (void)testReturnBlock_whenReturnURLDoesNotMatchHost_returnsFalseAndDoesNotCallOnComplete {
    WKScriptMessage *message = OCMClassMock([WKScriptMessage class]);
    OCMStub(message.body).andReturn(@{@"url": @"http://example.com/?hello=world"});
    OCMStub(message.name).andReturn(kPOPScriptMessageHandlerName);
    // Use strict mock to verify that webview does not call onComplete
    WKWebView *webView = OCMStrictClassMock([WKWebView class]);
    OCMStub([webView configuration]).andReturn(nil);

    POPPopupBridge *pub = [[POPPopupBridge alloc] initWithWebView:webView delegate:(id<POPViewControllerPresentingDelegate>)[[NSObject alloc] init]];
    [pub userContentController:[[WKUserContentController alloc] init] didReceiveScriptMessage:message];

    BOOL result = [POPPopupBridge openURL:[NSURL URLWithString:@"com.braintreepayments.popupbridgeexample://notcorrect/return?something=foo"] options:@{}];
    XCTAssertFalse(result);
}


// Test openURL:sourceApplication: and openURL:options:
- (void)testOpenURL_whenReturnBlockIsSet_returnsTrue {}

// Test openURL:sourceApplication: and openURL:options:
- (void)testOpenURL_whenReturnBlockIsNotSet_returnsFalse {}

- (void)testOpenURL_whenURLDoesNotMatchScheme_doesNotInvokeBlockAndReturnsFalse {}

// Consider adding tests for query parameter parsing - multiple values, special characters, encoded, etc.

@end
