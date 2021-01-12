#import <XCTest/XCTest.h>

@interface PopupBridge_DemoUITests : XCTestCase

@end

@implementation PopupBridge_DemoUITests {
    XCUIApplication *app;
}

#pragma mark - Setup

- (void)setUp {
    [super setUp];

    // In UI tests it is usually best to stop immediately when a failure occurs.
    self.continueAfterFailure = NO;
    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
    app = [[XCUIApplication alloc] init];
    [app launch];
}

#pragma mark - Helpers

- (void)waitForElement:(XCUIElement *)element timeout:(NSTimeInterval)timeout {
    [self expectationForPredicate:[NSPredicate predicateWithFormat:@"exists == 1"] evaluatedWithObject:element handler:nil];
    [self waitForExpectationsWithTimeout:timeout handler:nil];
}

- (void)runTestForColor:(NSString *)color {
    XCUIElementQuery *query = [app descendantsMatchingType:XCUIElementTypeWebView];
    XCUIElement *webView = [query elementBoundByIndex:0];

    XCUIElement *launchPopupButton = webView.buttons[@"Launch Popup"];
    [self waitForElement:launchPopupButton timeout:5];
    [launchPopupButton tap];

    XCUIElement *text = app.staticTexts[@"What's your favorite color?"];
    [self waitForElement:text timeout:10];

    XCUIElement *colorLink = app.links[color];
    [self waitForElement:colorLink timeout:5];

    [colorLink tap];

    [self waitForElement:app.staticTexts[@"PopupBridge Example"] timeout:5];
    [self waitForElement:app.staticTexts[@"Your favorite color:"] timeout:5];
    [self waitForElement:app.staticTexts[color.lowercaseString] timeout:5];
}

#pragma mark - Tests

- (void)testClickingColors_returnsColors {
    for (NSString *color in @[@"Red", @"Green", @"Blue"]) {
        [self runTestForColor:color];
    }
}

- (void)testClickingDoNotLikeColors_returnsDoNotLikeColors {
    XCUIElementQuery *query = [app descendantsMatchingType:XCUIElementTypeWebView];
    XCUIElement *webView = [query elementBoundByIndex:0];

    XCUIElement *launchPopupButton = webView.buttons[@"Launch Popup"];
    [self waitForElement:launchPopupButton timeout:5];
    [launchPopupButton tap];

    XCUIElement *text = app.staticTexts[@"What's your favorite color?"];
    [self waitForElement:text timeout:10];

    XCUIElement *doNotLikeLink = app.links[@"I don't like any of these colors"];
    [self waitForElement:doNotLikeLink timeout:10];

    [doNotLikeLink tap];

    [self waitForElement:app.staticTexts[@"You did not like any of our colors"] timeout:10];
}

- (void)testClickingSafariDone_returnsCancel {
    XCUIElementQuery *query = [app descendantsMatchingType:XCUIElementTypeWebView];
    XCUIElement *webView = [query elementBoundByIndex:0];

    XCUIElement *launchPopupButton = webView.buttons[@"Launch Popup"];
    [self waitForElement:launchPopupButton timeout:5];
    [launchPopupButton tap];

    XCUIElement *doneButton = app.buttons[@"Done"];
    [self waitForElement:doneButton timeout:5];
    [doneButton tap];

    [self waitForElement:app.staticTexts[@"You did not choose a color"] timeout:10];
}

@end
