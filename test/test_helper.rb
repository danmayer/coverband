require 'rubygems'
require 'simplecov'
require 'test/unit'
require 'mocha/setup'
require 'ostruct'
require 'json'
require 'pry-byebug' if ENV['PRY_BYEBUG']
require 'coverband_ext' if ENV['C_EXT']

SimpleCov.start do
  add_filter 'specs/ruby/1.9.1/gems/'
  add_filter '/test/'
  add_filter '/config/'
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
Mocha::Configuration.prevent(:stubbing_non_existent_method)

def test(name, &block)
  test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
  defined = instance_method(test_name) rescue false
  raise "#{test_name} is already defined in #{self}" if defined
  if block_given?
    define_method(test_name, &block)
  else
    define_method(test_name) do
      flunk "No implementation provided for #{name}"
    end
  end
end

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
