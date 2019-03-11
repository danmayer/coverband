# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

class CollectorsCoverageTest < Minitest::Test
  attr_accessor :coverband

  def setup
    super
    Coverband.configure do |config|
      config.store = Coverband::Adapters::RedisStore.new(Redis.new)
    end
    @coverband = Coverband::Collectors::Coverage.instance.reset_instance
  end

  def teardown
    Thread.current[:coverband_instance] = nil
    Coverband.configure do |config|
    end
    @coverband = Coverband::Collectors::Coverage.instance.reset_instance
  end

  test 'Empty coverage' do
    coverband.report_coverage(true)
    assert_equal({}, Coverband.configuration.store.coverage)
  end

  test 'Dog class coverage' do
    load File.expand_path('../../dog.rb', File.dirname(__FILE__))
    coverband.report_coverage(true)
    coverage = Coverband.configuration.store.coverage
    assert_equal(["./test/dog.rb"], coverage.keys)
    assert_equal(coverage["./test/dog.rb"]["data"], [nil, nil, 1, 1, 0, nil, nil])
  end

  test 'Dog method and class coverage' do
    load File.expand_path('../../dog.rb', File.dirname(__FILE__))
    Dog.new.bark
    coverband.report_coverage(true)
    coverage = Coverband.configuration.store.coverage
    assert_equal(["./test/dog.rb"], coverage.keys)
    assert_equal(coverage["./test/dog.rb"]["data"], [nil, nil, 1, 1, 1, nil, nil])
  end

  test 'gets coverage instance' do
    assert_equal Coverband::Collectors::Coverage, coverband.class
  end

  test 'defaults to a redis store' do
    assert_equal Coverband::Adapters::RedisStore, coverband.instance_variable_get('@store').class
  end

  test 'report_coverage raises errors in tests' do
    @coverband.reset_instance
    @coverband.expects(:ready_to_report?).raises('Oh no')
    assert_raises RuntimeError do
      @coverband.report_coverage
    end
  end

  test 'report_coverage does not raise errors in non-test mode' do
    Coverband.configuration.stubs(:test_env).returns(false)
    @coverband.expects(:ready_to_report?).raises('Oh no')
    @coverband.reset_instance
    @coverband.report_coverage
  end

  test 'default tmp ignores' do
    heroku_build_file = '/tmp/build_81feca8c72366e4edf020dc6f1937485/config/initializers/assets.rb'
    assert_equal false, @coverband.send(:track_file?, heroku_build_file)
  end
end
