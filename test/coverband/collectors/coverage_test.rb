# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))
require File.expand_path('../../dog', File.dirname(__FILE__))

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.3.0')
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

    test '#array_diff never returns negative hits' do
      # this can occur if a process forks after initializing the previous results
      # see test/benchmarks/coverage_fork.rb
      latest = [0, nil]
      original = [1, nil]
      expected = [0, nil]
      assert_equal expected, @coverband.send(:array_diff, latest, original)
    end
  end
end
