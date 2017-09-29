Pod::Spec.new do |s|
  s.name             = 'PopupBridge'
  s.version          = '0.1.1'
  s.summary          = 'Use PopupBridge to enable your web view to open pages in a Safari View Controller'
  s.description      = <<-DESC
PopupBridge is an iOS library that allows WKWebViews to open popup windows in an SFSafariViewController
browser and send data back to the WKWebView.

Use cases for PopupBridge:
* Apps with WebViews that need to open a popup
* When a popup window needs to to send data from the popup back to the WKWebView
* When the popup window needs to display the HTTPS lock icon to increase user trust
* Apps that use OAuth
                       DESC

  s.homepage         = 'https://github.com/braintree/popup-bridge-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Braintree' => 'code@getbraintree.com' }
  s.source           = { :git => 'https://github.com/braintree/popup-bridge-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'

  s.source_files = 'PopupBridge/Classes/**/*.{h,m}'
  s.public_header_files = 'PopupBridge/Classes/**/*.h'

  s.frameworks = 'UIKit', 'SafariServices'
end
