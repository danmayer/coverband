# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

class HTMLReportTest < Minitest::Test
  REDIS_STORAGE_FORMAT_VERSION = Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION

  def setup
    super
    @redis = Redis.new
    @store = Coverband::Adapters::RedisStore.new(@redis, redis_namespace: 'coverband_test')
    @store.clear!
  end

  test 'report data' do
    Coverband.configure do |config|
      config.reporter            = 'std_out'
      config.store               = @store
    end
    Coverband.configuration.logger.stubs('info')
    mock_file_hash
    Coverband.configuration
             .expects(:current_root)
             .at_least_once
             .returns('app_path')
    @store.send(:save_report, basic_coverage)

    report = Coverband::Reporters::ConsoleReport.report(@store)[:merged]
    expected = { './dog.rb' => [0, 1, 2] }
    assert_equal(expected.keys, report.keys)
  end
end
