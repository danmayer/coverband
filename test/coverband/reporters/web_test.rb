# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require File.expand_path("../../../lib/coverband/reporters/web", File.dirname(__FILE__))
require "rack/test"

ENV["RACK_ENV"] = "test"

module Coverband
  class WebTest < Minitest::Test
    include Rack::Test::Methods

    class FakeViewsTracker
      REPORT_ROUTE = "views_tracker"
      TITLE = "Views"

      attr_reader :used_keys

      def initialize(used_keys:)
        @used_keys = used_keys
      end

      def route
        REPORT_ROUTE
      end

      def title
        TITLE
      end

      def unused_keys
        []
      end

      def tracking_since
        "N/A"
      end

      def clear_key!(_key)
      end

      def reset_recordings
      end
    end

    def app
      Coverband::Reporters::Web.new
    end

    def teardown
      super
    end

    test "renders index content" do
      get "/"
      assert last_response.ok?
      assert_match "Coverband Home", last_response.body
    end

    test "renders index content for empty path" do
      get ""
      assert last_response.ok?
      assert_match "Coverband Home", last_response.body
    end

    test "renders 404" do
      get "/show"
      assert last_response.not_found?
      assert_equal "404 error!", last_response.body
    end

    test "clears coverband" do
      post "/clear"
      assert_equal 302, last_response.status
    end

    test "json endpoint accepts line_coverage parameter" do
      get "/json?line_coverage=true"
      assert last_response.ok?
    end

    test "renders static files" do
      get "/application.js"
      assert last_response.ok?
    end

    test "renders 404 if static file doesn't exist" do
      get "/unknown.js"
      assert last_response.not_found?
    end

    test "views tracker defaults to sorting used keys by last activity" do
      tracker = FakeViewsTracker.new(
        used_keys: {
          "app/views/a_first.html.erb" => "100",
          "app/views/z_latest.html.erb" => "200"
        }
      )

      Coverband.configuration.trackers = [tracker]
      get "/views_tracker"

      assert last_response.ok?
      first_index = last_response.body.index("app/views/a_first.html.erb")
      latest_index = last_response.body.index("app/views/z_latest.html.erb")
      assert latest_index < first_index
    end

    test "views tracker supports alpha sort toggle" do
      tracker = FakeViewsTracker.new(
        used_keys: {
          "app/views/z_latest.html.erb" => "200",
          "app/views/a_first.html.erb" => "100"
        }
      )

      Coverband.configuration.trackers = [tracker]
      get "/views_tracker?used_sort=alpha"

      assert last_response.ok?
      first_index = last_response.body.index("app/views/a_first.html.erb")
      latest_index = last_response.body.index("app/views/z_latest.html.erb")
      assert first_index < latest_index
    end
  end
end

module Coverband
  class AuthWebTest < Minitest::Test
    include Rack::Test::Methods

    def setup
      super
      @store = Coverband.configuration.store
      Coverband.configure do |config|
        config.password = "test_pass"
      end
    end

    def app
      Coverband::Reporters::Web.new
    end

    def teardown
      super
    end

    test "renders index with basic auth" do
      basic_authorize "anything", "test_pass"
      get "/"
      assert last_response.ok?
      assert_match "Coverband Home", last_response.body
    end

    test "renders 401 auth error when not provided" do
      get "/"
      assert_equal 401, last_response.status
    end
  end
end
