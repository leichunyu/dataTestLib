Pod::Spec.new do |s|
  s.name = "dataTestLib"
  s.version = "0.0.5"
  s.summary = "A demo for dataTestLib."
  s.license = {"type"=>"MIT", "file"=>"LICENSE"}
  s.authors = {"leichunyu"=>"leichunyu"}
  s.homepage = "https://github.com/leichunyu/dataTestLib"
  s.description = "TODO: Add long description of the pod here."
  s.frameworks = ["UIKit", "MapKit", "Security", "CoreLocation", "UserNotifications", "CoreData", "CoreTelephony", "MobileCoreServices", "JavaScriptCore", "CoreGraphics", "Foundation", "SystemConfiguration"]
  s.xcconfig = {"OTHER_LDFLAGS"=>"-ObjC"}
  s.source = { :path => '.' }

  s.ios.deployment_target    = '8.0'
  s.ios.vendored_framework   = 'ios/dataTestLib.framework'
  s.ios.libraries = ["c++", "stdc++", "z"]
end
