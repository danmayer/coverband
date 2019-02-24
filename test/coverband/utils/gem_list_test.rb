# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

####
# Thanks for all the help SimpleCov https://github.com/colszowka/simplecov-html
# initial version of test pulled into Coverband from Simplecov 12/19/2018
####
describe Coverband::Utils::GemList do
  subject do
    controller_lines = [nil, 2, 2, 0, nil, nil, 0, nil, nil, nil]
    gem_files = [
      Coverband::Utils::SourceFile.new(source_fixture('sample.rb'), [nil, 1, 1, 1, nil, nil, 1, 1, nil, nil]),
      Coverband::Utils::SourceFile.new(source_fixture('app/models/user.rb'), [nil, 1, 1, 1, nil, nil, 1, 0, nil, nil]),
      Coverband::Utils::SourceFile.new(source_fixture('app/controllers/sample_controller.rb'), controller_lines)
    ]
    gem_lists = [Coverband::Utils::FileList.new(gem_files), Coverband::Utils::FileList.new(gem_files)]
    Coverband::Utils::GemList.new(gem_lists)
  end

  it 'has 22 covered lines' do
    assert_equal 22, subject.covered_lines
  end

  it 'has 6 missed lines' do
    assert_equal 6, subject.missed_lines
  end

  it 'has 34 never lines' do
    assert_equal 34, subject.never_lines
  end

  it 'has 28 lines of code' do
    assert_equal 28, subject.lines_of_code
  end

  it 'has 10 skipped lines' do
    assert_equal 10, subject.skipped_lines
  end

  it 'has the correct covered percent' do
    assert_equal 78.57142857142857, subject.covered_percent
  end

  it 'has the correct covered strength' do
    assert_equal 0.9285714285714286, subject.covered_strength
  end
end
