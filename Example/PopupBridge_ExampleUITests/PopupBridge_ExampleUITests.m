#import <XCTest/XCTest.h>

@interface PopupBridge_ExampleUITests : XCTestCase

@end

@implementation PopupBridge_ExampleUITests {
    XCUIApplication *app;
}

- (void)setUp {
    [super setUp];
    
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;
    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
    app = [[XCUIApplication alloc] init];
    [app launch];
    
    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

//- (void)testDoneClosesSafariViewController

//- (void)testCancelClosesSafariViewController

- (void)testMakingAPurchase {
    XCUIElementQuery *query = [app descendantsMatchingType:XCUIElementTypeWebView];
    XCUIElement *webView = [query elementBoundByIndex:0];

    [webView swipeUp];
    [webView swipeUp];
    [webView swipeUp];
    [webView swipeUp];
    [webView swipeUp];

    [webView.buttons[@"PayPal Check out The safer, easier way to pay"] tap];

    XCUIElement *text = app.staticTexts[@"Mock Sandbox Purchase Flow"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"exists == 1"];
    [self expectationForPredicate:predicate evaluatedWithObject:text handler:nil];
    [self waitForExpectationsWithTimeout:5 handler:nil];
    XCTAssert(text.exists);

    [app.links[@"Proceed with Sandbox Purchase"] tap];

    [webView.buttons[@"Submit Transaction"] tap];

    [self expectationForPredicate:predicate evaluatedWithObject:app.staticTexts[@"SUCCESS"] handler:nil];
    [self waitForExpectationsWithTimeout:5 handler:nil];

    XCTAssert(app.staticTexts[@"SUCCESS"]);
    XCTAssert(app.staticTexts[@"payment method: PayPal"]);
    XCTAssert(app.staticTexts[@"status: authorized"]);
}

@end
