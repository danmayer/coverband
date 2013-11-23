require 'rubygems'
require 'simplecov'
require 'test/unit'
require 'shoulda'
require 'mocha'
require 'ostruct'
require 'json'

SimpleCov.start do
  add_filter 'specs/ruby/1.9.1/gems/'
  add_filter '/test/'
  add_filter '/config/'
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
Mocha::Configuration.prevent(:stubbing_non_existent_method)

require 'coverband'

unless File.exist?('./tmp/coverband_baseline.json')
  `mkdir -p ./tmp`
  `touch ./tmp/coverband_baseline.json`
end

Coverband.configure do |config|
  config.root              = Dir.pwd
  config.redis             = Redis.new
  #config.coverage_baseline = JSON.parse(File.read('./tmp/coverband_baseline.json'))
  config.root_paths        = ['/app/']
  config.ignore            = ['vendor']
  config.percentage        = 100.0
  config.reporter          = 'std_out'
end
