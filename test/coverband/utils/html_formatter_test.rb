# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class HTMLFormatterTest < Minitest::Test
  def setup
    super
    @store = Coverband::Adapters::RedisStore.new(Coverband::Test.redis, redis_namespace: "coverband_test")
  end

  test "generate dynamic content hosted html report" do
    Coverband.configure do |config|
      config.store = @store
      config.ignore = ["notsomething.rb"]
    end
    mock_file_hash
    @store.send(:save_report, basic_coverage_full_path)

    notice = nil
    base_path = "/coverage"
    filtered_report_files = Coverband::Reporters::Base.report(@store, {})
    html = Coverband::Utils::HTMLFormatter.new(filtered_report_files,
      base_path: base_path,
      notice: notice).format_dynamic_html!
    assert_match "loading source data", html
  end
end
