require File.expand_path('../test_helper', File.dirname(__FILE__))

class ReporterTest < Test::Unit::TestCase

  test "record baseline" do
    Coverage.expects(:start).returns(true).at_least_once
    Coverage.expects(:result).returns({'fake' => [0,1]}).at_least_once
    File.expects(:open).once

    Coverband::Baseline.stubs(:puts)

    Coverband::Baseline.record{
      #nothing
    }
  end

end
