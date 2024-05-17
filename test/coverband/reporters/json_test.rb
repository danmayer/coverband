# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class ReportJSONTest < Minitest::Test
  def setup
    super
    @store = Coverband.configuration.store
    Coverband.configure do |config|
      config.store = @store
      config.root = fixtures_root
      config.ignore = ["notsomething.rb", "lib/*"]
    end
    mock_file_hash
  end

  test "includes totals" do
    @store.send(:save_report, basic_coverage)

    json = Coverband::Reporters::JSONReport.new(@store).report
    parsed = JSON.parse(json)
    expected_keys = ["total_files", "lines_of_code", "lines_covered", "lines_missed", "covered_strength", "covered_percent"]
    assert expected_keys - parsed.keys == []
  end

  test "honors ignore list" do
    @store.send(:save_report, basic_coverage)

    json = Coverband::Reporters::JSONReport.new(@store).report
    parsed = JSON.parse(json)
    expected_files = ["app/controllers/sample_controller.rb", "app/models/user.rb"]
    assert_equal parsed["files"].keys, expected_files
  end

  test "includes metrics for files" do
    @store.send(:save_report, basic_coverage)

    json = Coverband::Reporters::JSONReport.new(@store).report
    parsed = JSON.parse(json)

    expected_keys = ["filename", "hash", "never_loaded", "runtime_percentage", "lines_of_code", "lines_covered", "lines_runtime", "lines_missed", "covered_percent", "covered_strength"]

    assert_equal parsed["files"].length, 2
    parsed["files"].keys.each do |file|
      assert_equal parsed["files"][file].keys, expected_keys
    end
  end

  test "supports merging" do
    @store.send(:save_report, basic_coverage)
    first_report = JSON.parse(Coverband::Reporters::JSONReport.new(@store, for_merged_report: true).report)

    @store.send(:save_report, increased_basic_coverage)
    second_report = JSON.parse(Coverband::Reporters::JSONReport.new(@store, for_merged_report: true).report)
    data = Coverband::Reporters::JSONReport.new(@store).merge_reports(first_report, second_report)
    assert_equal data[Coverband::RUNTIME_TYPE.to_s]["app_path/dog.rb"]["data"], [0, 4, 10]
    assert_equal data[Coverband::MERGED_TYPE.to_s]["app_path/dog.rb"]["data"], [0, 4, 10]
  end
end
