# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

class StandaloneJSONReportTest < Minitest::Test
  def skip_coverband_test_reset?
    true
  end

  def test_web_report_json_without_active_support
    Dir.mktmpdir("coverband-standalone") do |root|
      script = <<~'RUBY'
        require "coverband"
        require "rack/mock"

        Coverband.configure do |config|
          config.root = ARGV.fetch(0)
          config.store = Coverband::Adapters::NullStore.new
          config.background_reporting_enabled = false
          config.report_on_exit = false
          config.track_views = false
        end

        response = Rack::MockRequest.new(Coverband::Reporters::Web.new).get("/report_json")
        abort "unexpected status: #{response.status}" unless response.status == 200
        puts response.body
      RUBY
      output, error, status = Open3.capture3(
        {"COVERBAND_DISABLE_AUTO_START" => "1"},
        RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), "-e", script, root,
        chdir: root
      )

      assert status.success?, error
      data = JSON.parse(output)
      assert_equal [], data.fetch("aaData")
      assert_equal 0, data.fetch("iTotalRecords")
      assert_equal 0, data.fetch("iTotalDisplayRecords")
      assert_equal "unsupported", data.dig("storage_health", "coverage", "status")
    end
  end
end
