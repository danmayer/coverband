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
    # preload first coverage hit
    @coverband.report_coverage
  end

  def teardown
    Thread.current[:coverband_instance] = nil
    Coverband.configure do |config|
    end
    @coverband = Coverband::Collectors::Coverage.instance.reset_instance
  end

  test 'Dog class coverage' do
    file = require_unique_file
    coverband.report_coverage
    coverage = Coverband.configuration.store.coverage
    assert_equal(coverage[file]['data'], [nil, nil, 1, 1, 0, nil, nil])
  end

  test 'Dog method and class coverage' do
    load File.expand_path('../../dog.rb', File.dirname(__FILE__))
    Dog.new.bark
    coverband.report_coverage
    coverage = Coverband.configuration.store.coverage
    assert_equal(coverage['./test/dog.rb']['data'], [nil, nil, 1, 1, 1, nil, nil])
  end

  test 'Dog eager load coverage' do
    store = Coverband.configuration.store
    assert_nil store.type
    file = coverband.eager_loading do
      require_unique_file
    end
    coverage = Coverband.configuration.store.coverage[file]
    assert_nil coverage, 'No runtime coverage'
    coverband.eager_loading!
    coverage = Coverband.configuration.store.coverage[file]
    refute_nil coverage, 'Eager load coverage is present'
    assert_equal(coverage['data'], [nil, nil, 1, 1, 0, nil, nil])
  end

  test 'gets coverage instance' do
    assert_equal Coverband::Collectors::Coverage, coverband.class
  end

  test 'defaults to a redis store' do
    assert_equal Coverband::Adapters::RedisStore, coverband.instance_variable_get('@store').class
  end

  test 'report_coverage raises errors in tests' do
    Coverband::Adapters::RedisStore.any_instance.stubs(:save_report).raises('Oh no')
    @coverband.reset_instance
    assert_raises RuntimeError do
      @coverband.report_coverage
    end
  end

  test 'report_coverage raises errors in tests with verbose enabled' do
    Coverband.configuration.verbose = true
    logger = mock
    Coverband.configuration.logger = logger
    @coverband.reset_instance
    Coverband::Adapters::RedisStore.any_instance.stubs(:save_report).raises('Oh no')
    logger.expects(:error).times(3)
    error = assert_raises RuntimeError do
      @coverband.report_coverage
    end
    assert_match /Oh no/, error.message
  end

  test 'default tmp ignores' do
    heroku_build_file = '/tmp/build_81feca8c72366e4edf020dc6f1937485/config/initializers/assets.rb'
    assert_equal false, @coverband.send(:track_file?, heroku_build_file)
  end

  test 'one shot line coverage disabled for ruby >= 2.6' do
    return unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.5.0')
    Coverband::Collectors::Coverage.expects(:ruby_version_greater_than_or_equal_to?).with('2.6.0').returns(true)
    ::Coverage.expects(:running?).returns(false)
    ::Coverage.expects(:start).with(oneshot_lines: false)
    Coverband::Collectors::Coverage.send(:new)
  end

  test 'one shot line coverage enabled for ruby >= 2.6' do
    return unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.5.0')
    Coverband.configuration.expects(:use_oneshot_lines_coverage).returns(true)
    Coverband::Collectors::Coverage.expects(:ruby_version_greater_than_or_equal_to?).with('2.6.0').returns(true)
    ::Coverage.expects(:running?).returns(false)
    ::Coverage.expects(:start).with(oneshot_lines: true)
    Coverband::Collectors::Coverage.send(:new)
  end

  test 'one shot line coverage for ruby >= 2.6 when already running' do
    return unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.5.0')
    Coverband::Collectors::Coverage.expects(:ruby_version_greater_than_or_equal_to?).with('2.6.0').returns(true)
    ::Coverage.expects(:running?).returns(true)
    ::Coverage.expects(:start).never
    Coverband::Collectors::Coverage.send(:new)
  end

  test 'no one shot line coverage for ruby < 2.6' do
    return unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.5.0')
    Coverband::Collectors::Coverage.expects(:ruby_version_greater_than_or_equal_to?).with('2.6.0').returns(false)
    Coverband::Collectors::Coverage.expects(:ruby_version_greater_than_or_equal_to?).with('2.5.0').returns(true)
    ::Coverage.expects(:running?).returns(false)
    ::Coverage.expects(:start).with()
    Coverband::Collectors::Coverage.send(:new)
  end
end
