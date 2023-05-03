Pod::Spec.new do |s|
  s.name             = 'PopupBridge'
  s.version          = '1.2.0'
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

  s.ios.deployment_target = '14.0'
  s.swift_version    = "5.8"
  
  s.source_files = 'Sources/PopupBridge/**/*.swift'
end
