# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))
require File.expand_path('./dog', File.dirname(__FILE__))

class CollectorsBaseTest < Test::Unit::TestCase
  def setup
    Coverband.configure do |config|
      config.collector         = 'trace'
    end
  end

  test 'defaults to a redis store' do
    coverband = Coverband::Collectors::Base.instance.reset_instance
    assert_equal Coverband::Adapters::RedisStore, coverband.instance_variable_get('@store').class
  end

  test 'configure memory caching' do
    Coverband.configuration.memory_caching = true
    coverband = Coverband::Collectors::Base.instance.reset_instance
    assert_equal Coverband::Adapters::MemoryCacheStore, coverband.instance_variable_get('@store').class
    Coverband.configuration.memory_caching = false
  end

  test 'start should enable coverage' do
    coverband = Coverband::Collectors::Base.instance.reset_instance
    assert_equal false, coverband.instance_variable_get('@enabled')
    coverband.expects(:record_coverage).once
    coverband.start
    assert_equal true, coverband.instance_variable_get('@enabled')
  end

  test 'stop should disable coverage' do
    coverband = Coverband::Collectors::Base.instance.reset_instance
    assert_equal false, coverband.instance_variable_get('@enabled')
    coverband.expects(:record_coverage).once
    coverband.start
    assert_equal true, coverband.instance_variable_get('@enabled')
    coverband.stop
    assert_equal false, coverband.instance_variable_get('@enabled')
  end

  test 'allow for sampling with a block and enable when 100 percent sample' do
    logger = Logger.new(STDOUT)
    coverband = Coverband::Collectors::Base.instance.reset_instance
    coverband.instance_variable_set('@sample_percentage', 100.0)
    coverband.instance_variable_set('@verbose', true)
    coverband.instance_variable_set('@logger', logger)
    coverband.instance_variable_set('@store', nil)
    assert_equal false, coverband.instance_variable_get('@enabled')
    logger.expects(:info).at_least_once
    logger.stubs('debug')
    coverband.sample { 1 + 1 }
    assert_equal true, coverband.instance_variable_get('@enabled')
  end

  test 'allow reporting with start stop save' do
    logger = Logger.new(STDOUT)
    coverband = Coverband::Collectors::Base.instance.reset_instance
    coverband.instance_variable_set('@sample_percentage', 100.0)
    coverband.instance_variable_set('@verbose', true)
    coverband.instance_variable_set('@logger', logger)
    coverband.instance_variable_set('@store', nil)
    assert_equal false, coverband.instance_variable_get('@enabled')
    logger.expects(:info).at_least_once
    logger.stubs('debug')
    coverband.start
    coverband.stop
    coverband.save
  end

  test 'allow reporting to redis start stop save' do
    dog_file = File.expand_path('./dog.rb', File.dirname(__FILE__))
    coverband = Coverband::Collectors::Base.instance.reset_instance
    coverband.instance_variable_set('@sample_percentage', 100.0)
    coverband.instance_variable_set('@verbose', true)
    Coverband.configuration.logger.stubs('info')
    Coverband.configuration.logger.stubs('debug')
    store = Coverband::Adapters::RedisStore.new(Redis.new)
    coverband.instance_variable_set('@store', store)
    store.expects(:save_report).once.with(has_entries(dog_file => {5 => 5}))
    assert_equal false, coverband.instance_variable_get('@enabled')
    coverband.start
    5.times { Dog.new.bark }
    coverband.stop
    coverband.save
  end

  test 'tracer should count line numbers' do
    dog_file = File.expand_path('./dog.rb', File.dirname(__FILE__))
    coverband = Coverband::Collectors::Base.instance.reset_instance
    coverband.start
    100.times { Dog.new.bark }
    Coverband::Collectors::Base.instance
    assert_equal 100, coverband.instance_variable_get('@file_line_usage')[dog_file][5]
    coverband.stop
    coverband.save
  end

  test 'sample should return the result of the block' do
    coverband = Coverband::Collectors::Base.instance.reset_instance
    assert_equal 2, coverband.sample { 1 + 1 }
  end
end
