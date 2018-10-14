# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class SimpleCovReportTest < Test::Unit::TestCase
  BASE_KEY = Coverband::Adapters::RedisStore::BASE_KEY

  def setup
    @redis = Redis.new
    @redis.flushdb
    @store = Coverband::Adapters::RedisStore.new(@redis)
  end

  test 'report data' do
    Coverband.configure do |config|
      config.reporter            = 'std_out'
      config.store               = @store
      config.reporting_frequency = 100.0
    end
    Coverband.configuration.logger.stubs('info')
    Coverband::Reporters::ConsoleReport.expects(:current_root).returns('./test/unit')
    @store.send(:save_report, basic_coverage)

    report = Coverband::Reporters::ConsoleReport.report(@store)
    expected = {"test/unit/dog.rb"=>[0, 1, 2]}
    assert_equal(expected, report)
  end
end
