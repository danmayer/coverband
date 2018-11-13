# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class CoverbandTest < Test::Unit::TestCase

  test 'Coverband#start kicks off background reporting if enabled and not in rack server' do
    Coverband.configuration.stubs(:background_reporting_enabled).returns(:true)
    Coverband::RackServerCheck.expects(:running?).returns(false)
    Coverband::Background.expects(:start)
    Coverband.start
  end

  test 'Coverband#start delays background reporting if enabled and running in a rack server' do
    Coverband.configuration.stubs(:background_reporting_enabled).returns(true)
    Coverband::RackServerCheck.expects(:running?).returns(true)
    Coverband::Background.expects(:start).never
    Coverband.start
  end

  test 'Coverband#start does not kick off background reporting if not enabled' do
    Coverband.configuration.stubs(:background_reporting_enabled).returns(false)
    Coverband::Background.expects(:start).never
    ::Coverband.start
  end
end
