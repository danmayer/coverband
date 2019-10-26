# frozen_string_literal: true

require File.expand_path('../../test_helper', File.dirname(__FILE__))

class BackgroundTest < Minitest::Test
  class ThreadDouble < Struct.new(:alive)
    def exit; end

    def alive?
      alive
    end
  end

  def test_start
    Thread.expects(:new).yields.returns(ThreadDouble.new(true))
    Coverband::Background.expects(:loop).yields
    Coverband::Background.expects(:sleep).with(30)
    Coverband::Collectors::Coverage.instance.expects(:report_coverage).once
    2.times { Coverband::Background.start }
  end

  def test_start_with_wiggle
    Thread.expects(:new).yields.returns(ThreadDouble.new(true))
    Coverband::Background.expects(:loop).yields
    Coverband::Background.expects(:sleep).with(35)
    Coverband::Background.expects(:rand).with(10).returns(5)
    Coverband.configuration.reporting_wiggle = 10
    Coverband::Collectors::Coverage.instance.expects(:report_coverage).once
    2.times { Coverband::Background.start }
  end

  def test_start_dead_thread
    Thread.expects(:new).yields.returns(ThreadDouble.new(false)).twice
    Coverband::Background.expects(:loop).yields.twice
    Coverband::Background.expects(:sleep).with(30).twice
    Coverband::Collectors::Coverage.instance.expects(:report_coverage).twice
    2.times { Coverband::Background.start }
  end
end
