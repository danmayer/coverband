require 'rubygems'
require 'simplecov'
require 'test/unit'
require 'mocha/setup'
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

def fake_redis
  @redis ||= begin
    redis = OpenStruct.new()
    def redis.smembers(key)
    end
    redis
  end
end

def fake_coverband_members
  ["/Users/danmayer/projects/hearno/script/tester.rb",
   "/Users/danmayer/projects/hearno/app/controllers/application_controller.rb",
   "/Users/danmayer/projects/hearno/app/models/account.rb"
  ]
end

def fake_coverage_report
  {"/Users/danmayer/projects/hearno/script/tester.rb"=>[1, nil, 1, 1, nil, nil, nil]}
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
