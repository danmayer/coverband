# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class ReporterTest < Test::Unit::TestCase
  test 'record baseline' do
    Coverband.configure do |config|
      config.redis             = nil
      config.store             = nil
      config.root              = '/full/remote_app/path'
      config.coverage_file     = '/tmp/fake_file.json'
    end
    Coverage.expects(:start).returns(true).at_least_once
    Coverage.expects(:result).returns('fake' => [0, 1]).at_least_once
    File.expects(:open).once

    File.expects(:exist?).at_least_once.returns(true)
    expected = { 'filename.rb' => [0, nil, 1] }
    fake_file_data = expected.to_json
    File.expects(:read).at_least_once.returns(fake_file_data)

    Coverband::Baseline.record do
      # nothing
    end
  end

  test 'parse baseline' do
    Coverband.configure do |config|
      config.redis             = nil
      config.store             = nil
      config.root              = '/full/remote_app/path'
      config.coverage_file     = '/tmp/fake_file.json'
    end
    File.expects(:exist?).at_least_once.returns(true)
    expected = { 'filename.rb' => [0, nil, 1] }
    fake_file_data = expected.to_json
    File.expects(:read).at_least_once.returns(fake_file_data)
    results = Coverband::Baseline.parse_baseline
    assert_equal(results, 'filename.rb' => [0, nil, 1])
  end

  test 'exclude_files' do
    Coverband.configure do |config|
      config.redis             = nil
      config.store             = nil
      config.root              = '/full/remote_app/path'
      config.coverage_file     = '/tmp/fake_file.json'
      config.ignore            = ['ignored_file.rb']
    end
    root = Coverband.configuration.root
    files = [root + '/ignored_file.rb', root + '/fakefile.rb']
    expected_files = [root + '/fakefile.rb']
    assert_equal(expected_files, Coverband::Baseline.exclude_files(files))
  end
  
  test 'convert_coverage_format' do
    results = { 'fake_file.rb' => [1, nil, 0, 2] }
    expected = { 'fake_file.rb' => { 1 => 1, 3 => 0, 4 => 2 } }
    assert_equal(expected, Coverband::Baseline.convert_coverage_format(results))
  end
end
