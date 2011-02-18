$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.dirname(__FILE__), '**','*')

require 'rubygems'
require 'bundler/setup'

require 'rspec'
require 'fake_ftp' # and any other gems you need

RSpec.configure do |config|
  
end