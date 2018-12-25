# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class BackgroundTest < Minitest::Test
  def setup
    super
    Coverband.configure do |config|
      config.store = Coverband::Adapters::RedisStore.new(Redis.new)
      config.background_reporting_enabled = true
      config.background_reporting_sleep_seconds = 30
    end
  end

  def test_start
    Thread.expects(:new).yields.returns(:thread)
    Coverband::Background.expects(:loop).yields

    Coverband::Background.expects(:sleep).with(30)
    Coverband::Background.expects(:at_exit).returns(false)
    Coverband::Collectors::Coverage.instance.expects(:report_coverage).once
    2.times { Coverband::Background.start }
  end
end
