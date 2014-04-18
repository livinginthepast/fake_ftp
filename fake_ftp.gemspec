# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "fake_ftp/version"

Gem::Specification.new do |s|
  s.name        = "fake_ftp"
  s.version     = FakeFtp::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Colin Shield", "Eric Saxby"]
  s.email       = ["sax+github@livinginthepast.org"]
  s.homepage    = "http://rubygems.org/gems/fake_ftp"
  s.summary     = %q{Creates a fake FTP server for use in testing}
  s.description = %q{Testing FTP? Use this!}
  s.license     = 'MIT'

  s.required_rubygems_version = ">= 1.3.6"
  
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
