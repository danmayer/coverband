# frozen_string_literal: true

require File.expand_path("../rails_test_helper", File.dirname(__FILE__))

class RailsWithoutConfigStackTest < Minitest::Test
  def setup
    super
    setup_server
  end

  def teardown
    super
    shutdown_server
  end

  test "check view tracker" do
    output = `sleep 7 && curl http://localhost:9999/dummy_view/show`
    assert output.match(/rendered view/)
    assert output.match(/I am no dummy view tracker text/)
    output = `sleep 2 && curl http://localhost:9999/coverage/views_tracker`
    assert output.match(/Used Views: \(1\)/)
    assert output.match(/dummy_view\/show/)
  end

  private

  # NOTE: We aren't leveraging Capybara because it loads all of our other test helpers and such,
  # which in turn Configures coverband making it impossible to test the configuration error
  def setup_server
    ENV["RAILS_ENV"] = "test"
    require "rails"
    fork do
      exec "cd test/rails#{Rails::VERSION::MAJOR}_dummy && COVERBAND_TEST=test bundle exec rackup config.ru -p 9999 --pid /tmp/testrack.pid"
    end
  end

  def shutdown_server
    if File.exist?("/tmp/testrack.pid")
      pid = `cat /tmp/testrack.pid`&.strip&.to_i
      Process.kill("HUP", pid)
      sleep 1
    end
  end
end
