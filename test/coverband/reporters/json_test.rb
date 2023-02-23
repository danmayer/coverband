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

    expected_keys = ["never_loaded", "runtime_percentage", "lines_of_code", "lines_covered", "lines_missed", "covered_percent", "covered_strength"]

    assert_equal parsed["files"].length, 2
    parsed["files"].keys.each do |file|
      assert_equal parsed["files"][file].keys, expected_keys
    end
  end
end
