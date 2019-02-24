# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

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
    Coverband.configuration.expects(:gem_paths).at_least_once.returns([FAKE_GEM_PATH])
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

describe Coverband::Utils::FileGroups, :vendored_gems do
  FAKE_VENDOR_GEM_PATH = "#{test_root}/app/vendor/bundle/ruby/2.5.0/gems"
  subject do
    controller_lines = [nil, 2, 2, 0, nil, nil, 0, nil, nil, nil]
    files = [
      Coverband::Utils::SourceFile.new(source_fixture('sample.rb'), [nil, 1, 1, 1, nil, nil, 1, 1, nil, nil]),
      Coverband::Utils::SourceFile.new(source_fixture('app/models/user.rb'), [nil, 1, 1, 1, nil, nil, 1, 0, nil, nil]),
      Coverband::Utils::SourceFile.new(source_fixture('app/controllers/sample_controller.rb'), controller_lines),
      Coverband::Utils::SourceFile.new("#{FAKE_VENDOR_GEM_PATH}/gem_name.rb", controller_lines)
    ]
    Coverband.configuration.expects(:gem_paths).at_least_once.returns([FAKE_VENDOR_GEM_PATH])
    Coverband.configuration.track_gems = true
    Coverband::Utils::FileGroups.new(files)
  end

  it 'has app files' do
    assert_equal 'test/fixtures/sample.rb', subject.grouped_results['App'].first.short_name
  end

  it "doesn't include vendor gems in app files app files" do
    assert_nil subject.grouped_results['App'].select { |files| files.short_name.match(/gem_name/) }.first
  end

  it 'does has gem files' do
    assert_equal 'gem_name.rb', subject.grouped_results['Gems'].first.first.short_name
  end
end
