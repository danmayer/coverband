# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "./lib/coverband/collectors/delta"

class CollectorsDeltaTest < Minitest::Test
  class MockSystemCoverage < Struct.new(:results)
  end

  def mock_coverage(coverage)
    MockSystemCoverage.new(coverage)
  end

  def setup
    Coverband::Collectors::Delta.reset
    Coverband::Collectors::Delta.class_variable_set(:@@project_directory, "car.rb")
  end

  test "No previous results" do
    current_coverage = {
      "car.rb" => [0, 5, 1]
    }
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal(current_coverage, results)
  end

  test "Coverage has gone up" do
    current_coverage = {
      "car.rb" => [nil, 1, 5, 1]
    }
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal(current_coverage, results)

    current_coverage = {
      "car.rb" => [nil, 1, 7, 1]
    }
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal({"car.rb" => [nil, 0, 2, 0]}, results)
  end

  test "New file added to coverage" do
    current_coverage = {}
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal(current_coverage, results)

    current_coverage = {
      "dealership.rb" => [nil, 1, 1, nil]
    }
    Coverband::Collectors::Delta.class_variable_set(:@@project_directory, "dealership.rb")
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal(current_coverage, results)
  end

  test "default tmp ignores" do
    heroku_build_file = "/tmp/build_81feca8c72366e4edf020dc6f1937485/config/initializers/assets.rb"

    current_coverage = {
      heroku_build_file => [0, 5, 1]
    }
    Coverband::Collectors::Delta.class_variable_set(:@@project_directory, heroku_build_file)
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal({}, results)
  end

  # verifies a fix where we were storing, merging, and tracking ignored files
  # then just filtering them out of the final report
  test "ignores uses regex same as reporter does" do
    regex_file = Coverband.configuration.current_root + "/config/initializers/fake.rb"

    current_coverage = {
      regex_file => [0, 5, 1]
    }

    Coverband::Collectors::Delta.class_variable_set(:@@project_directory, regex_file)
    Coverband::Collectors::Delta.class_variable_set(:@@ignore_patterns, ["config/initializers/*"])
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal({}, results)
  end

  test "Coverage has branching enabled and has gone up" do
    current_coverage = {
      "car.rb" => {lines: [nil, 1, 5, 1]}
    }
    ::Coverage.expects(:peek_result).returns(current_coverage)
    Coverband::Collectors::Delta.results

    current_coverage = {
      "car.rb" => {lines: [nil, 1, 7, 1]}
    }
    ::Coverage.expects(:peek_result).returns(current_coverage)
    results = Coverband::Collectors::Delta.results
    assert_equal({"car.rb" => [nil, 0, 2, 0]}, results)
  end

  test "oneshot coverage calls clear" do
    Coverband.configuration.stubs(:use_oneshot_lines_coverage).returns(true)
    current_coverage = {
      "car.rb" => [1, 5]
    }

    ::Coverage.expects(:result).with(clear: true, stop: false).returns(current_coverage)
    Coverband::Collectors::Delta::RubyCoverage.results
  end

  test "one shot lines results" do
    Coverband.configuration.stubs(:use_oneshot_lines_coverage).returns(true)
    current_coverage = {}
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal(current_coverage, results)

    current_coverage = {
      "dealership.rb" => {
        oneshot_lines: [2, 3]
      }
    }
    Coverband::Collectors::Delta.class_variable_set(:@@project_directory, "dealership.rb")
    ::Coverage.expects(:line_stub).with("dealership.rb").returns([nil, 0, 0, nil])
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    expected = {
      "dealership.rb" => [nil, 1, 1, nil]
    }
    assert_equal(expected, results)
  end
end
