# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

####
# Thanks for all the help SimpleCov https://github.com/colszowka/simplecov-html
# initial version of test pulled into Coverband from Simplecov 12/19/2018
####
describe Coverband::Utils::FileGroups do
  FAKE_GEM_PATH = 'fake/gem/path'
  subject do
    controller_lines = [nil, 2, 2, 0, nil, nil, 0, nil, nil, nil]
    files = [
      Coverband::Utils::SourceFile.new(source_fixture('sample.rb'), [nil, 1, 1, 1, nil, nil, 1, 1, nil, nil]),
      Coverband::Utils::SourceFile.new(source_fixture('app/models/user.rb'), [nil, 1, 1, 1, nil, nil, 1, 0, nil, nil]),
      Coverband::Utils::SourceFile.new(source_fixture('app/controllers/sample_controller.rb'), controller_lines),
      Coverband::Utils::SourceFile.new("#{FAKE_GEM_PATH}/gem_name.rb", controller_lines)
    ]
    Coverband.configuration.expects(:gem_paths).returns([FAKE_GEM_PATH])
    Coverband.configuration.track_gems = true
    Coverband::Utils::FileGroups.new(files)
  end

  it 'has app files' do
    assert_equal 'test/fixtures/sample.rb', subject.grouped_results['App'].first.short_name
  end

  it 'has gem files' do
    assert_equal "#{FAKE_GEM_PATH}/gem_name.rb", subject.grouped_results['Gems'].first.first.short_name
  end
end
