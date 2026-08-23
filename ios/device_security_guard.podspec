Pod::Spec.new do |s|
  s.name             = 'device_security_guard'
  s.version          = '0.1.0'
  s.summary          = 'Device security signals and policy helpers for Flutter.'
  s.description      = <<-DESC
Detects rooted, jailbroken, hooked, debugged, emulated, repackaged, and unlocked environments.
                       DESC
  s.homepage         = 'https://pub.dev/packages/device_security_guard'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Van Nghia'
  s.source           = { :path => '.' }
  s.source_files = 'device_security_guard/Sources/device_security_guard/**/*.swift'
  s.dependency 'Flutter'
  s.frameworks = 'Security'
  s.platform = :ios, '15.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
  s.resource_bundles = {
    'device_security_guard_privacy' => [
      'device_security_guard/Sources/device_security_guard/PrivacyInfo.xcprivacy'
    ]
  }
end
