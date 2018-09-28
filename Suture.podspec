Pod::Spec.new do |s|
  s.name             = 'Suture'
  s.version          = '0.2.1'
  s.summary          = 'Future support for Swift.'


  s.description      = <<-DESC
This library adds future support for Swift.
                       DESC

  s.homepage         = 'https://github.com/cristik/Suture'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'cristik' => 'kocza.cristian@gmail.com' }
  s.source           = { :git => 'https://github.com/cristik/Suture.git', :tag => s.version.to_s }

  s.platform = :osx, :ios
  s.osx.deployment_target = "10.10"
  s.ios.deployment_target = "9.0"
  s.swift_version = "4.1"

  s.source_files = 'src/*.swift'
end
