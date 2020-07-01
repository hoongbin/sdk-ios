#
# Be sure to run `pod lib lint BetaDataSDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'BetaDataSDK'
  s.version          = '1.2.19'
  s.summary          = 'The official iOS SDK for BetaData Analytics.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
The official iOS SDK for BetaData Analytics. Supports iOS 8+.
                       DESC

  s.homepage         = 'http://code.mocaapp.cn/betadata/sdk-ios.git'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Zhou Kang' => 'dev.zhoukang@gmail.com' }
  s.source           = { :git => 'http://code.mocaapp.cn/betadata/sdk-ios.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'BetaDataSDK/Classes/**/*'
  s.resource  = 'BetaDataSDK/Assets/*.bundle'
  
  # s.resource_bundles = {
  #   'BetaDataSDK' => ['BetaDataSDK/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'FCUUID'
end
