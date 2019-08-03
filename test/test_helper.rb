# frozen_string_literal: true

# This lets us ignore warnings from our test dependencies when loaded
# We do this because of aws-sdk-s3
# aws-sdk-s3 is written in such a way to cause dozens of warnings
original_verbosity = $VERBOSE
$VERBOSE = nil
require 'rubygems'
require 'aws-sdk-s3'
require 'simplecov'
require 'coveralls'
require 'minitest/autorun'
require 'mocha/minitest'
require 'ostruct'
require 'json'
require 'redis'
require 'resque'
require 'pry-byebug'
require_relative 'unique_files'
$VERBOSE = original_verbosity

unless ENV['ONESHOT'] || ENV['SIMULATE_ONESHOT']
  SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  SimpleCov.start do
    add_filter 'test/forked'
  end

  Coveralls.wear!
end

module Coverband
  module Test
    def self.reset
      Coverband.configuration.redis_namespace = 'coverband_test'
      Coverband.configuration.store.instance_variable_set(:@redis_namespace, 'coverband_test')
      Coverband.configuration.store.class.class_variable_set(:@@path_cache, {})
      %i[eager_loading runtime].each do |type|
        Coverband.configuration.store.type = type
        Coverband.configuration.store.clear!
      end
      Coverband.configuration.reset
      Coverband::Collectors::Coverage.instance.reset_instance
      Coverband::Utils::RelativeFileConverter.reset
      Coverband::Utils::AbsoluteFileConverter.reset
      Coverband.configuration.redis_namespace = 'coverband_test'
      Coverband::Background.stop
    end

    def setup
      super
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
  Coverband::Utils::FileHasher.expects(:hash).at_least_once.returns('abcd')
end

def example_line
  [0, 1, 2]
end

def basic_coverage
  { 'app_path/dog.rb' => example_line }
end

def basic_coverage_full_path
  { basic_coverage_file_full_path => example_line }
end

def basic_source_fixture_coverage
  { source_fixture('sample.rb') => example_line }
end

def basic_coverage_file_full_path
  "#{test_root}/dog.rb"
end

def source_fixture(filename)
  File.expand_path(File.join(File.dirname(__FILE__), 'fixtures', filename))
end

def fixtures_root
  File.expand_path(File.join(File.dirname(__FILE__), 'fixtures'))
end

def test_root
  File.expand_path(File.join(File.dirname(__FILE__)))
end

###
# This handles an issue where the store is setup in tests prior to being able to set the namespace
###
def store
  if Coverband.configuration.store.redis_namespace == 'coverband_test'
    Coverband.configuration.store
  else
    Coverband.configuration.redis_namespace = 'coverband_test'
    Coverband.configuration.instance_variable_set(:@store, nil)
    Coverband.configuration.store
  end
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
