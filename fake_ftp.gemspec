# -*- encoding: utf-8 -*-
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))
require 'fake_ftp/version'

Gem::Specification.new do |s|
  s.name = 'fake_ftp'
  s.version = FakeFtp::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Colin Shield', 'Eric Saxby']
  s.email = ['sax+github@livinginthepast.org']
  s.homepage = 'http://rubygems.org/gems/fake_ftp'
  s.summary = 'Creates a fake FTP server for use in testing'
  s.description = 'Testing FTP? Use this!'
  s.license = 'MIT'

  s.files = `git ls-files -z`.split("\0")
  s.test_files = `git ls-files -z -- spec/*`.split("\0")
  s.require_paths = %w[lib]
end
