# frozen_string_literal: true

require 'rubygems'
require 'simplecov'
require 'test/unit'
require 'mocha/setup'
require 'ostruct'
require 'json'
require 'redis'

SimpleCov.start do
  add_filter 'specs/ruby/1.9.1/gems/'
  add_filter '/test/'
  add_filter '/config/'
end

TEST_COVERAGE_FILE = '/tmp/fake_file.json'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
Mocha::Configuration.prevent(:stubbing_non_existent_method)

def test(name, &block)
  test_name = "test_#{name.gsub(/\s+/, '_')}".to_sym
  defined = begin
              instance_method(test_name)
            rescue StandardError
              false
            end
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
    redis = OpenStruct.new
    # mocha requires method to exist to mock it
    def redis.smembers(key); end
    def redis.hgetall(key); end
    redis
  end
end

def fake_coverband_members
  ['/Users/danmayer/projects/hearno/script/tester.rb',
   '/Users/danmayer/projects/hearno/app/controllers/application_controller.rb',
   '/Users/danmayer/projects/hearno/app/models/account.rb']
end

def fake_coverage_report
  { '/Users/danmayer/projects/hearno/script/tester.rb' => [1, nil, 1, 1, nil, nil, nil] }
end

require 'coverband'

Coverband.configure do |config|
  config.root                = Dir.pwd
  config.root_paths          = ['/app/']
  config.ignore              = ['vendor']
  config.reporting_frequency = 100.0
  config.reporter            = 'std_out'
  config.store               = Coverband::Adapters::RedisStore.new(Redis.new)
end
