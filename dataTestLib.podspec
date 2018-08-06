#
# Be sure to run `pod lib lint dataTestLib.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'dataTestLib'
  s.version          = '0.1.0'
  s.summary          = 'A demo for dataTestLib.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/leichunyu/dataTestLib'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'leichunyu' => 'leichunyu' }
  s.source           = { :git => 'https://github.com/leichunyu/dataTestLib.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  #s.source_files = 'dataTestLib/Classes/**/*','dataTestLib/Resource/**/DatatistTracker.xcdatamodeld'
  s.source_files = 'lib/include/*.h'
   s.public_header_files = 'lib/include/*.h'
  s.vendored_libraries = 'lib/*.a'
   s.frameworks = 'UIKit', 'MapKit', 'Security', 'CoreLocation', 'UserNotifications', 'CoreData', 'CoreTelephony', 'MobileCoreServices', 'JavaScriptCore', 'CoreGraphics', 'Foundation', 'SystemConfiguration'
  s.ios.library = 'c++', 'stdc++', 'z'
  s.xcconfig = { 'OTHER_LDFLAGS' => '-ObjC' }
  
   #s.resource_bundles = 'dataTestLib/Assets/**/*.png'
  s.resource_bundles = {
    'dataTestLib' => 'lib/**/*.png'
}
   #s.public_header_files = 'dataTestLib/Classes/DatatistCouponInfo.h', 'dataTestLib/Classes/DatatistDispatcher.h', 'dataTestLib/Classes/DatatistNSURLSessionDispatcher.h', 'dataTestLib/Classes/DatatistOrderInfo.h', 'dataTestLib/Classes/DatatistProductInfo.h', 'dataTestLib/Classes/DatatistTracker.h', 'dataTestLib/Classes/DatatistTransaction.h', 'dataTestLib/Classes/DatatistTransactionBuilder.h'
   #s.resources = "dataTestLib/Resource/**/*"
  s.frameworks = 'UIKit', 'MapKit', 'Security', 'CoreLocation', 'UserNotifications', 'CoreData', 'CoreTelephony', 'MobileCoreServices', 'JavaScriptCore', 'CoreGraphics', 'Foundation', 'SystemConfiguration', 'WebKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  s.dependency 'WebViewJavascriptBridge'
end
