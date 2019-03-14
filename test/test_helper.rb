# frozen_string_literal: true

# This lets us ignore warnings from our test dependencies when loaded
# We do this because of aws-sdk-s3
# aws-sdk-s3 is written in such a way to cause dozens of warnings
original_verbosity = $VERBOSE
$VERBOSE = nil
require 'rubygems'
require 'aws-sdk-s3'
require 'coveralls'
require 'simplecov'
require 'minitest/autorun'
require 'mocha/minitest'
require 'ostruct'
require 'json'
require 'redis'
require 'resque'
require 'pry-byebug'
require 'minitest/fork_executor'
require 'simplecov'
$VERBOSE = original_verbosity
Minitest.parallel_executor = Minitest::ForkExecutor.new

#Coveralls.wear!



module Coverband
  module Test
    def self.reset
      Coverband.configuration.store.clear!
      Coverband.configuration.reset
      Coverband::Collectors::Coverage.instance.reset_instance
      Coverband::Background.stop
    end

    
    def setup
      super
      SimpleCov.start
      SimpleCov.command_name "#{Process.pid}"
      Coverband::Test.reset
    end
  end
end

Minitest::Test.class_eval do
  prepend Coverband::Test
end

TEST_COVERAGE_FILE = '/tmp/fake_file.json'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

Mocha::Configuration.prevent(:stubbing_method_unnecessarily)
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

def mock_file_hash
  mock_file = mock('mock_file')
  mock_file.expects(:hexdigest).at_least_once.returns('abcd')
  Digest::MD5.expects(:file).at_least_once.returns(mock_file)
end

def example_line
  [0, 1, 2]
end

def basic_coverage
  { 'app_path/dog.rb' => example_line }
end

def fake_redis
  @redis ||= begin
    redis = OpenStruct.new
    redis
  end
end

def fake_coverage_report
  file_name = '/Users/danmayer/projects/hearno/script/tester.rb'
  { file_name => [1, nil, 1, 1, nil, nil, nil] }
end

def source_fixture(filename)
  File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', filename))
end

def test_root
  File.expand_path(File.join(File.dirname(__FILE__)))
end

# Taken from http://stackoverflow.com/questions/4459330/how-do-i-temporarily-redirect-stderr-in-ruby
def capture_stderr
  # The output stream must be an IO-like object. In this case we capture it in
  # an in-memory IO object so we can return the string value. You can assign any
  # IO object here.
  previous_stderr = $stderr
  $stderr = StringIO.new
  yield
  $stderr.string
ensure
  # Restore the previous value of stderr (typically equal to STDERR).
  $stderr = previous_stderr
end

require 'coverband'

Coverband::Configuration.class_eval do
  def test_env
    true
  end
end
