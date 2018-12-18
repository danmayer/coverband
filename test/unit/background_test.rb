# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))

class BackgroundTest < Test::Unit::TestCase
  def setup
    Coverband::Collectors::Coverage.instance.reset_instance
    Coverband.configure do |config|
      config.store = Coverband::Adapters::RedisStore.new(Redis.new)
      config.background_reporting_enabled = true
      config.background_reporting_sleep_seconds = 30
    end
    Coverband::Background.instance_variable_set(:@background_reporting_running, nil)
  end

  def test_start
    Thread.expects(:new).yields
    Coverband::Background.expects(:loop).yields

    Coverband::Background.expects(:sleep).with(30)
    Coverband::Background.expects(:at_exit).yields
    Coverband::Collectors::Coverage.instance.expects(:report_coverage).twice
    2.times { Coverband::Background.start }
  end
end
