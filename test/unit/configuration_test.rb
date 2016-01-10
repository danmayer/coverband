require File.expand_path('../test_helper', File.dirname(__FILE__))

class BaseTest < Test::Unit::TestCase

  test "defaults to line trace point event" do
    assert_equal Coverband.configuration.trace_point_events, [:line]
  end
end
