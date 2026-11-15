# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class CollectorsCoverageTest < Minitest::Test
  attr_accessor :coverband

  def setup
    super
    @coverband = Coverband::Collectors::Coverage.instance
    # preload first coverage hit
    @coverband.report_coverage
  end

  def teardown
    Thread.current[:coverband_instance] = nil
    Coverband.configure do |config|
    end
    @coverband = Coverband::Collectors::Coverage.instance.reset_instance
  end

  test "Dog class coverage" do
    file = require_unique_file
    coverband.report_coverage
    coverage = Coverband.configuration.store.coverage
    assert_equal(coverage[file]["data"], [nil, nil, 1, 1, 0, nil, nil, 1, nil, 1, nil, nil])
  end

  test "Dog method and class coverage" do
    load File.expand_path("../../dog.rb", File.dirname(__FILE__))
    Dog.new.bark
    coverband.report_coverage
    coverage = Coverband.configuration.store.coverage
    assert_equal(coverage["./test/dog.rb"]["data"], [nil, nil, 1, 1, 1, nil, nil, 1, nil, 1, nil, nil])
  end

  test "Dog eager load coverage" do
    store = Coverband.configuration.store
    assert_equal Coverband::RUNTIME_TYPE, store.type
    file = coverband.eager_loading {
      require_unique_file
    }
    coverage = Coverband.configuration.store.coverage[file]
    assert_nil coverage, "No runtime coverage"
    coverband.eager_loading!
    coverage = Coverband.configuration.store.coverage[file]
    refute_nil coverage, "Eager load coverage is present"
    assert_equal(coverage["data"], [nil, nil, 1, 1, 0, nil, nil, 1, nil, 1, nil, nil])
  end

  test "Dog eager load coverage is dropped untransformed when the deferred data is never sent" do
    Coverband.configure do |config|
      config.defer_eager_loading_data = true
      config.send_deferred_eager_loading_data = false
    end
    # the collector is a singleton, so deferred data from another test may still be around
    coverband.instance_variable_set(:@deferred_eager_loading_data, nil)
    Coverband::Collectors::Delta.expects(:results).never
    file = coverband.eager_loading {
      require_unique_file
    }
    assert_nil coverband.instance_variable_get(:@deferred_eager_loading_data)
    Coverband::Collectors::Delta.unstub(:results)

    coverband.report_coverage
    assert_nil Coverband.configuration.store.coverage[file], "eager loaded lines are not reported as runtime coverage"
    coverband.eager_loading!
    assert_nil Coverband.configuration.store.coverage[file], "No eager load coverage is stored"
  end

  test "Dog eager load coverage is still deferred when the deferred data is sent" do
    Coverband.configure do |config|
      config.defer_eager_loading_data = true
      config.send_deferred_eager_loading_data = true
    end
    coverband.instance_variable_set(:@deferred_eager_loading_data, nil)
    file = coverband.eager_loading {
      require_unique_file
    }
    deferred = coverband.instance_variable_get(:@deferred_eager_loading_data)
    assert deferred.key?(File.expand_path(file)), "eager load coverage is kept until the first runtime report"

    coverband.report_coverage
    coverband.eager_loading!
    coverage = Coverband.configuration.store.coverage[file]
    refute_nil coverage, "Eager load coverage is sent with the first runtime report"
    assert_equal(coverage["data"], [nil, nil, 1, 1, 0, nil, nil, 1, nil, 1, nil, nil])
  end

  test "gets coverage instance" do
    assert_equal Coverband::Collectors::Coverage, coverband.class
  end

  test "defaults to a redis store" do
    assert_equal Coverband::Adapters::RedisStore, coverband.instance_variable_get(:@store).class
  end

  test "report_coverage raises errors in tests" do
    Coverband::Adapters::RedisStore.any_instance.stubs(:save_report).raises("Oh no")
    @coverband.reset_instance
    assert_raises RuntimeError do
      @coverband.report_coverage
    end
  end

  test "report_coverage raises errors in tests with verbose enabled" do
    Coverband.configuration.verbose = true
    logger = mock
    Coverband.configuration.logger = logger
    @coverband.reset_instance
    Coverband::Adapters::RedisStore.any_instance.stubs(:save_report).raises("Oh no")
    logger.expects(:error).at_least(3)
    error = assert_raises RuntimeError do
      @coverband.report_coverage
    end
    assert_match %r{Oh no}, error.message
  end

  test "using coverage state idle with ruby >= 3.1.0" do
    ::Coverage.expects(:state).returns(:idle)
    ::Coverage.expects(:start).with(oneshot_lines: false)
    Coverband::Collectors::Coverage.send(:new)
  end

  test "using coverage state suspended with ruby >= 3.1.0" do
    ::Coverage.expects(:state).returns(:suspended).at_least_once
    ::Coverage.expects(:resume)
    Coverband::Collectors::Coverage.send(:new)
  end
end
