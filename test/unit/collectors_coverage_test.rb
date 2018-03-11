# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))
require File.expand_path('./dog', File.dirname(__FILE__))

class CollectorsCoverageTest < Test::Unit::TestCase
  attr_accessor :coverband

  def setup
    Thread.current[:coverband_instance] = nil
    Coverband.configure do |config|
      config.collector = 'coverage'
    end
    @coverband = Coverband::Collectors::Base.instance.reset_instance
  end

  def teardown
    Thread.current[:coverband_instance] = nil
    Coverband.configure do |config|
      config.collector = 'trace'
    end
    @coverband = Coverband::Collectors::Base.instance.reset_instance
  end

  test 'gets coverage instance' do
    assert_equal Coverband::Collectors::Coverage, coverband.class
  end

  test 'defaults to a redis store' do
    assert_equal Coverband::Adapters::RedisStore, coverband.instance_variable_get('@store').class
  end

  test 'configure memory caching' do
    Coverband.configuration.memory_caching = true
    coverband = Coverband::Collectors::Base.instance.reset_instance
    assert_equal Coverband::Adapters::MemoryCacheStore, coverband.instance_variable_get('@store').class
    Coverband.configuration.memory_caching = false
  end

  test 'start should enable coverage' do
    assert_equal false, coverband.instance_variable_get('@enabled')
    coverband.expects(:record_coverage).once
    coverband.start
    assert_equal true, coverband.instance_variable_get('@enabled')
  end

  test 'stop should disable coverage' do
    assert_equal false, coverband.instance_variable_get('@enabled')
    coverband.expects(:record_coverage).once
    coverband.start
    assert_equal true, coverband.instance_variable_get('@enabled')
    coverband.stop
    assert_equal false, coverband.instance_variable_get('@enabled')
  end

  test 'allow for sampling with a block and enable when 100 percent sample' do
    logger = Logger.new(STDOUT)
    coverband.instance_variable_set('@sample_percentage', 100.0)
    coverband.instance_variable_set('@verbose', true)
    coverband.instance_variable_set('@logger', logger)
    coverband.instance_variable_set('@store', nil)
    assert_equal false, coverband.instance_variable_get('@enabled')
    logger.expects(:info).at_least_once
    coverband.sample { 1 + 1 }
    assert_equal true, coverband.instance_variable_get('@enabled')
  end

  test 'allow reporting with start stop save' do
    logger = Logger.new(STDOUT)
    coverband.instance_variable_set('@sample_percentage', 100.0)
    coverband.instance_variable_set('@verbose', true)
    coverband.instance_variable_set('@logger', logger)
    coverband.instance_variable_set('@store', nil)
    assert_equal false, coverband.instance_variable_get('@enabled')
    logger.expects(:info).at_least_once
    coverband.start
    1 + 1
    coverband.stop
    coverband.save
  end

  test 'allow reporting to redis start stop save' do
    dog_file = File.expand_path('./dog.rb', File.dirname(__FILE__))
    coverband.instance_variable_set('@sample_percentage', 100.0)
    coverband.instance_variable_set('@verbose', true)
    Coverband.configuration.logger.stubs('info')
    store = Coverband::Adapters::RedisStore.new(Redis.new)
    coverband.instance_variable_set('@store', store)

    prior = Coverage.peek_result[dog_file].dup
    prior[4] = prior[4] + 5
    expected = {}
    prior.each_with_index do |count, index|
      expected[(index + 1)] = count if count
    end

    store.expects(:save_report).once.with(has_entries(dog_file => expected))
    assert_equal false, coverband.instance_variable_get('@enabled')
    coverband.start
    5.times { Dog.new.bark }
    coverband.stop
    coverband.save
  end

  test 'coverage should count line numbers only the new calls' do
    dog_file = File.expand_path('./dog.rb', File.dirname(__FILE__))
    coverband.instance_variable_set('@sample_percentage', 100.0)
    coverband.instance_variable_set('@store', nil)
    original_count = Coverage.peek_result[dog_file][4]
    coverband.start
    100.times { Dog.new.bark }
    coverband.stop
    coverband.save
    assert_equal (original_count + 100), coverband.instance_variable_get('@file_line_usage')[dog_file][5]
    50.times { Dog.new.bark }
    coverband.save
    assert_equal 50, coverband.instance_variable_get('@file_line_usage')[dog_file][5]
  end

  test 'coverage should count line numbers' do
    dog_file = File.expand_path('./dog.rb', File.dirname(__FILE__))
    coverband.instance_variable_set('@sample_percentage', 100.0)
    coverband.instance_variable_set('@store', nil)
    original_count = Coverage.peek_result[dog_file][4]
    coverband.start
    100.times { Dog.new.bark }
    coverband.stop
    coverband.save
    assert_equal (original_count + 100), coverband.instance_variable_get('@file_line_usage')[dog_file][5]
  end

  test 'sample should return the result of the block' do
    assert_equal 2, coverband.sample { 1 + 1 }
  end
end
