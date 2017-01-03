require File.expand_path('../test_helper', File.dirname(__FILE__))

class ReporterTest < Test::Unit::TestCase

  test "record baseline" do
    Coverband.configure do |config|
      config.redis             = nil
      config.store             = nil
      config.root              = '/full/remote_app/path'
      config.coverage_file     = '/tmp/fake_file.json'
    end
    Coverage.expects(:start).returns(true).at_least_once
    Coverage.expects(:result).returns({'fake' => [0,1]}).at_least_once
    File.expects(:open).once

    File.expects(:exist?).at_least_once.returns(true)
    expected = {"filename.rb" => [0,nil,1]}
    fake_file_data = expected.to_json
    File.expects(:read).at_least_once.returns(fake_file_data)

    Coverband::Baseline.record{
      #nothing
    }
  end

  test "parse baseline" do
    Coverband.configure do |config|
      config.redis             = nil
      config.store             = nil
      config.root              = '/full/remote_app/path'
      config.coverage_file     = '/tmp/fake_file.json'
    end
    File.expects(:exist?).at_least_once.returns(true)
    expected = {"filename.rb" => [0,nil,1]}
    fake_file_data = expected.to_json
    File.expects(:read).at_least_once.returns(fake_file_data)
    results = Coverband::Baseline.parse_baseline
    assert_equal({"filename.rb" => [0,nil,1]}, results)
  end

  # todo test redis and file baseline
  # todo test conversion to sparse hash format
end