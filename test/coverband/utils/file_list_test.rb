# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

####
# Thanks for all the help SimpleCov https://github.com/colszowka/simplecov-html
# initial version of test pulled into Coverband from Simplecov 12/19/2018
####
describe Coverband::Utils::FileList do
  subject do
    original_result = {
      source_fixture('sample.rb') => [nil, 1, 1, 1, nil, nil, 1, 1, nil, nil],
      source_fixture('app/models/user.rb') => [nil, 1, 1, 1, nil, nil, 1, 0, nil, nil],
      source_fixture('app/controllers/sample_controller.rb') => [nil, 2, 2, 0, nil, nil, 0, nil, nil, nil]
    }
    Coverband::Utils::Result.new(original_result).files
  end

  it 'has 11 covered lines' do
    assert_equal 11, subject.covered_lines
  end

  it 'has 3 missed lines' do
    assert_equal 3, subject.missed_lines
  end

  it 'has 17 never lines' do
    assert_equal 17, subject.never_lines
  end

  it 'has 14 lines of code' do
    assert_equal 14, subject.lines_of_code
  end

  it 'has 5 skipped lines' do
    assert_equal 5, subject.skipped_lines
  end

  it 'has the correct covered percent' do
    assert_equal 78.57142857142857, subject.covered_percent
  end

  it 'has the correct covered percentages' do
    assert_equal [50.0, 80.0, 100.0], subject.covered_percentages
  end

  it 'has the correct covered strength' do
    assert_equal 0.9285714285714286, subject.covered_strength
  end
end
