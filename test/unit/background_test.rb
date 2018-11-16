# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class BackgroundTest < Test::Unit::TestCase
  def test_start
    Thread.expects(:new).yields
    Coverband::Background.expects(:loop).yields
    Coverband::Collectors::Coverage.instance.expects(:report_coverage)
    Coverband::Background.expects(:sleep).with(30)
    Coverband::Background.expects(:at_exit).yields
    Coverband::Collectors::Coverage.instance.expects(:report_coverage)
    2.times { Coverband::Background.start }
  end
end

