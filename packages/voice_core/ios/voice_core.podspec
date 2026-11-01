#
# iOS build of the OffTopic voice core (C++17), linked statically into the app.
# Dart opens it with DynamicLibrary.process(). Prepared in phase 0, exercised
# in phase 7 (iPhone as a client); it needs a Mac to build.
#
Pod::Spec.new do |s|
  s.name             = 'voice_core'
  s.version          = '0.1.0'
  s.summary          = 'OffTopic native voice core (audio, codec, network).'
  s.description      = 'C++17 voice core of OffTopic, exposed to Dart through dart:ffi.'
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'OffTopic contributors'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*', '../include/voice_core.h'
  s.public_header_files = '../include/voice_core.h'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/../include" "${PODS_TARGET_SRCROOT}/../src"',
    'GCC_SYMBOLS_PRIVATE_EXTERN' => 'YES',
  }
  s.swift_version = '5.0'
end
