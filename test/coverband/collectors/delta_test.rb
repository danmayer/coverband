# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))
require './lib/coverband/collectors/delta'

class CollectorsDeltaTest < Minitest::Test
  class MockSystemCoverage < Struct.new(:results)
  end

  def mock_coverage(coverage)
    MockSystemCoverage.new(coverage)
  end

  def setup
    Coverband::Collectors::Delta.reset
  end

  test 'No previous results' do
    current_coverage = {
      'car.rb' => [0, 5, 1]
    }
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal(current_coverage, results)
  end

  test 'Coverage has gone up' do
    current_coverage = {
      'car.rb' => [nil, 1, 5, 1]
    }
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal(current_coverage, results)

    current_coverage = {
      'car.rb' => [nil, 1, 7, 1]
    }
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal({ 'car.rb' => [nil, 0, 2, 0] }, results)
  end

  test 'New file added to coverage' do
    current_coverage = {}
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal(current_coverage, results)

    current_coverage = {
      'dealership.rb' => [nil, 1, 1, nil]
    }
    results = Coverband::Collectors::Delta.results(mock_coverage(current_coverage))
    assert_equal(current_coverage, results)
  end

  test 'one shot lines results' do
    unless Coverband.configuration.one_shot_coverage_implemented_in_ruby_version?
      module ::Coverage
        def self.line_stub(file)
        end
      end
    end

    Coverband.configuration.stubs(:use_oneshot_lines_coverage).returns(true)
    current_coverage = {}
    ::Coverage.expects(:peek_result).returns(current_coverage)
    results = Coverband::Collectors::Delta.results
    assert_equal(current_coverage, results)

    current_coverage = {
      'dealership.rb' => {
        :oneshot_lines => [2,3]
      }
    }
    ::Coverage.expects(:line_stub).with('dealership.rb').returns([nil, 0, 0, nil])
    ::Coverage.expects(:peek_result).returns(current_coverage)
    results = Coverband::Collectors::Delta.results
    expected = {
      'dealership.rb' => [nil, 1, 1, nil]
    }
    assert_equal(expected, results)
  end
end
