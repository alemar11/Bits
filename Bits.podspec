Pod::Spec.new do |s|
  s.name    = 'Bits'
  s.version = '0.5.1'
  s.license = 'MIT'
  s.documentation_url = 'http://www.tinrobots.org/Bits'  
  s.summary   = 'Bits.'
  s.homepage  = 'https://github.com/tinrobots/Bits'
  s.authors   = { 'Alessandro Marzoli' => 'me@alessandromarzoli.com' }
  s.source    = { :git => 'https://github.com/tinrobots/Bits.git', :tag => s.version }
  s.requires_arc = true
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5'}
  
  s.swift_version = "5"
  s.ios.deployment_target     = '11.0'
  s.osx.deployment_target     = '10.13'
  #s.tvos.deployment_target    = '11.0'
  #s.watchos.deployment_target = '4.0'

  s.source_files =  'Sources/**/*.swift',
                    'Support/*.{h,m}'
end
