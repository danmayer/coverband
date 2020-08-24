# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

class BackgroundTest < Minitest::Test
  class ThreadDouble < Struct.new(:alive)
    def exit
    end

    def alive?
      alive
    end
  end

  def setup
    Coverband.configuration.reset
    super
    Coverband.configure do |config|
      config.background_reporting_sleep_seconds = 60
      Coverband.configuration.reporting_wiggle = 0
    end
  end

  def test_start
    sleep_seconds = Coverband.configuration.background_reporting_sleep_seconds.to_i
    Thread.expects(:new).yields.returns(ThreadDouble.new(true))
    Coverband::Background.expects(:loop).yields
    Coverband::Background.expects(:sleep).with(sleep_seconds)
    Coverband::Collectors::Coverage.instance.expects(:report_coverage).once
    2.times { Coverband::Background.start }
  end

  def test_start_with_wiggle
    sleep_seconds = Coverband.configuration.background_reporting_sleep_seconds.to_i
    Thread.expects(:new).yields.returns(ThreadDouble.new(true))
    Coverband::Background.expects(:loop).yields
    Coverband::Background.expects(:sleep).with(sleep_seconds + 5)
    Coverband::Background.expects(:rand).with(10).returns(5)
    Coverband.configuration.reporting_wiggle = 10
    Coverband::Collectors::Coverage.instance.expects(:report_coverage).once
    2.times { Coverband::Background.start }
  end

  def test_start_dead_thread
    Thread.expects(:new).yields.returns(ThreadDouble.new(false)).twice
    Coverband::Background.expects(:loop).yields.twice
    Coverband::Background.expects(:sleep).with(60).twice
    Coverband::Collectors::Coverage.instance.expects(:report_coverage).twice
    2.times { Coverband::Background.start }
  end
end
