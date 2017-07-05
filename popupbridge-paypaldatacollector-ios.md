## One-time payments

Device data is identified with a client metadata ID.

Implement the method that receives the popup URL and use this sample code to parse the `clientMetadataID`:

```objectivec
// In your POPPopupBridgeDelegate
- (void)popupBridge:(POPPopupBridge *)bridge willOpenURL:(NSURL *)url {
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name IN %@", @[@"token", @"ba_token"]];
    NSURLQueryItem *queryItem = [[components.queryItems filteredArrayUsingPredicate:predicate] firstObject];
    NSString *clientMetadataId = queryItem.value;
    
    // Call PayPal Data Collector
    NSString *result = [PPDataCollector clientMetadataID:clientMetadataId];
    NSLog(@"Called PPDataCollector clientMetadataID:%@ and got %@", clientMetadataId, result);
}
```

The call to `+[PPDataCollector clientMetadataID:]` causes device data to be collected and sent to PayPal. The `result` is the client metadata ID. Typically, you do not need to do anything else with it.

## Charging a vaulted PayPal account

1. Create a global JavaScript function on your web page to receive the device data object and [provide it to your server](https://developers.braintreepayments.com/guides/paypal/vault/javascript/v3#collecting-device-data), e.g. by injecting it into your form as a hidden input.
```javascript
window.setDeviceData = function setDeviceData(deviceData) {
  console.log('Web view got device data:', deviceData);
  // TODO: Set hidden input value with deviceData so that it is submitted to your server on form submit.
  //       Then, pass it with Transaction.sale and the vaulted PayPal account payment method token.
}
```
2. Implement the method that receives messages from the web view. Use this sample code to collect device data and pass the device data object back to the web page (by calling your global function):
```objectivec
// In your POPPopupBridgeDelegate
- (void)popupBridge:(POPPopupBridge *)bridge receivedMessage:(NSString *)messageName data:(NSString *)data {
    if ([messageName isEqualToString:@"requestDeviceData"]) {
        NSString *deviceData = [PPDataCollector collectPayPalDeviceData];
        [self.webView evaluateJavaScript:[NSString stringWithFormat:@"window.setDeviceData(%@);", deviceData] completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error: Unable to set device data. Details: %@", error.description);
            }
        }];
    }
}
```
3. On your web page, send a message to PopupBridge to request device data.
```javascript
window.popupBridge.sendMessage('requestDeviceData');
```

If you have questions, create an issue for this GitHub project.
