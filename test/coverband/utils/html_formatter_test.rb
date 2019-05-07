# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

class HTMLFormatterTest < Minitest::Test
  def setup
    super
    @redis = Redis.new
    @store = Coverband::Adapters::RedisStore.new(@redis)
    @store.clear!
  end

  test 'generate dynamic content hosted html report' do
    Coverband.configure do |config|
      config.store             = @store
      config.s3_bucket         = nil
      config.ignore            = ['notsomething.rb']
    end
    mock_file_hash
    @store.send(:save_report, basic_coverage_full_path)

    notice = nil
    base_path = '/coverage'
    filtered_report_files = Coverband::Reporters::Base.report(@store, {})
    html = Coverband::Utils::HTMLFormatter.new(filtered_report_files,
                                               base_path: base_path,
                                               notice: notice).format_dynamic_html!
    assert_match 'loading source data', html
  end

  test 'generate static HTML report file' do
    Coverband.configure do |config|
      config.store             = @store
      config.s3_bucket         = nil
      config.ignore            = ['notsomething.rb']
    end
    mock_file_hash
    @store.send(:save_report, basic_coverage_full_path)

    filtered_report_files = Coverband::Reporters::Base.report(@store, {})
    Coverband::Utils::HTMLFormatter.new(filtered_report_files).format_static_html!
    html = File.read("#{Coverband.configuration.root}/coverage/index.html")
    assert_match 'Coverage first seen', html
  end
end
