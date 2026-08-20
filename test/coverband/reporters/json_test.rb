# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class ReportJSONTest < Minitest::Test
  def setup
    super
    @store = Coverband.configuration.store
    Coverband.configure do |config|
      config.store = @store
      config.root = fixtures_root
      config.ignore = ["notsomething.rb", /\/lib\//]
    end
    mock_file_hash
  end

  test "includes totals" do
    @store.send(:save_report, basic_coverage)

    json = Coverband::Reporters::JSONReport.new(@store).report
    parsed = JSON.parse(json)
    expected_keys = ["total_files", "lines_of_code", "lines_covered", "lines_missed", "covered_strength", "covered_percent"]
    assert expected_keys - parsed.keys == []
    assert_equal "ok", parsed.dig("storage_health", "coverage", "status")
  end

  test "does not add storage health to merged report JSON" do
    @store.send(:save_report, basic_coverage)

    parsed = JSON.parse(Coverband::Reporters::JSONReport.new(@store, for_merged_report: true).report)

    refute_includes parsed, "storage_health"
    assert_includes parsed, Coverband::RUNTIME_TYPE.to_s
  end

  test "storage health describes the report's store" do
    @store.send(:save_report, basic_coverage)
    configured_store = @store
    report_store = Object.new
    report_store.define_singleton_method(:get_coverage_report) do |options|
      configured_store.get_coverage_report(options)
    end

    parsed = JSON.parse(Coverband::Reporters::JSONReport.new(report_store).report)

    assert_equal "unsupported", parsed.dig("storage_health", "coverage", "status")
  end

  test "honors ignore list" do
    @store.send(:save_report, basic_coverage)

    json = Coverband::Reporters::JSONReport.new(@store).report
    parsed = JSON.parse(json)
    expected_files = ["app/controllers/sample_controller.rb", "app/models/user.rb"]
    assert_equal parsed["files"].keys.sort, expected_files.sort
  end

  test "includes metrics for files" do
    @store.send(:save_report, basic_coverage)

    json = Coverband::Reporters::JSONReport.new(@store).report
    parsed = JSON.parse(json)

    expected_keys = ["filename", "hash", "never_loaded", "first_updated_at", "last_updated_at", "runtime_percentage", "lines_of_code", "lines_covered", "lines_runtime", "lines_missed", "covered_percent", "covered_strength"]

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
