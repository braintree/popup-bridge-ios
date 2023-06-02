source 'https://cdn.cocoapods.org/'

platform :ios, '14.0'
workspace 'PopupBridge.xcworkspace'

use_frameworks!

target 'UnitTests' do
  project 'PopupBridge'
  pod 'xcbeautify'
end

# Workaround required for Xcode 14.3 
# https://stackoverflow.com/questions/75574268/missing-file-libarclite-iphoneos-a-xcode-14-3
post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      end
    end
  end
end