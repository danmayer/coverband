require File.expand_path('../test_helper', File.dirname(__FILE__))

class ReporterTest < Test::Unit::TestCase

  test "record baseline" do
    Coverage.expects(:start).returns(true).at_least_once
    Coverage.expects(:result).returns({'fake' => [0,1]}).at_least_once
    File.expects(:open).once

    File.expects(:exist?).at_least_once.returns(true)
    expected = {"filename.rb" => [0,nil,1]}
    fake_file_data = expected.to_json
    File.expects(:read).at_least_once.returns(fake_file_data)

    Coverband::Baseline.stubs(:puts)

    Coverband::Baseline.record{
      #nothing
    }
  end

  test "parse baseline" do
    File.expects(:exist?).once.returns(true)
    expected = {"filename.rb" => [0,nil,1]}
    fake_file_data = expected.to_json
    File.expects(:read).returns(fake_file_data)
    results = Coverband::Baseline.parse_baseline("fake_file.json")
    assert_equal({"filename.rb" => [0,nil,1]}, results)
  end

end
