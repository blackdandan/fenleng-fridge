Pod::Spec.new do |s|
  s.name             = 'fenleng_sdk_flutter_native_identity'
  s.version          = '0.1.0'
  s.summary          = 'Optional native identity providers for Fenleng Flutter clients.'
  s.homepage         = 'https://github.com/blackdandan/fenleng-client-sdk'
  s.license          = { :type => 'Proprietary', :text => 'Copyright Fenleng Engineering' }
  s.author           = { 'Fenleng Engineering' => 'engineering@fenlengtech.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  # Authorization uses no payment symbols. Match legacy fluwx_no_pay consumers.
  s.dependency 'OpenWeChatSDKNoPay', '2.0.5'
  s.platform = :ios, '13.0'
  s.static_framework = true
  s.swift_version = '5.0'
end
