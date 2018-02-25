# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class BaseTest < Test::Unit::TestCase
  test 'defaults to line trace point event' do
    assert_equal Coverband.configuration.trace_point_events, [:line]
  end

  test 'defaults to ignore gems' do
    assert_equal Coverband.configuration.include_gems, false
    coverband = Coverband::Base.instance.reset_instance
    assert_equal ['vendor', 'internal:prelude', 'schema.rb', 'gems'], coverband.instance_variable_get('@ignore_patterns')
  end

  test "doesn't ignore gems if include_gems = true" do
    Coverband.configuration.include_gems = true
    coverband = Coverband::Base.instance.reset_instance
    assert_equal ['vendor', 'internal:prelude', 'schema.rb'], coverband.instance_variable_get('@ignore_patterns')
  end
end
