# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class HTMLReportTest < Minitest::Test
  REDIS_STORAGE_FORMAT_VERSION = Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION

  def setup
    super
    @redis = Redis.new
    @store = Coverband::Adapters::RedisStore.new(@redis)
    @store.clear!
  end

  test 'report data' do
    Coverband.configure do |config|
      config.reporter            = 'std_out'
      config.store               = @store
      config.reporting_frequency = 100.0
    end
    Coverband.configuration.logger.stubs('info')
    mock_file_hash
    Coverband::Reporters::ConsoleReport
      .expects(:current_root)
      .returns('app_path')
    @store.send(:save_report, basic_coverage)

    report = Coverband::Reporters::ConsoleReport.report(@store)
    expected = { 'app_path/dog.rb' => [0, 1, 2] }
    assert_equal(expected.keys, report.keys)
  end
end
