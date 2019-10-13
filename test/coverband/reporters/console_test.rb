# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

class HTMLReportTest < Minitest::Test
  REDIS_STORAGE_FORMAT_VERSION = Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION

  def setup
    super
    @store = Coverband.configuration.store
  end

  test 'report data' do
    Coverband.configure do |config|
      config.reporter = 'std_out'
    end
    Coverband.configuration.logger.stubs('info')
    mock_file_hash
    Coverband::Utils::RelativeFileConverter.expects(:convert).with('app_path/dog.rb').returns('./dog.rb')
    @store.send(:save_report, basic_coverage)

    report = Coverband::Reporters::ConsoleReport.report(@store)[:merged]
    expected = { './dog.rb' => [0, 1, 2] }
    assert_equal(expected.keys, report.keys)
  end
end
