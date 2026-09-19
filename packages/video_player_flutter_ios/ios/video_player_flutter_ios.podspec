#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'video_player_flutter_ios'
  s.version          = '0.0.1'
  s.summary          = 'AVPlayer HLS backend for video_player_flutter'
  s.description      = 'Low-memory AVPlayer texture player'
  s.homepage         = 'https://github.com/vorzela/video_player_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Vorzela' => 'dev@vorzela.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
