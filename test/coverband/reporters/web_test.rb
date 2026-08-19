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

    ###
    # A reset whose pointer write did not land has not happened. Reporting it as
    # done leaves the operator believing data is gone when it is not.
    ###
    test "failed tracker reset is reported as a failure" do
      Coverband.configuration.stubs(:web_enable_clear).returns(true)
      tracker = FakeViewsTracker.new(used_keys: {})
      tracker.define_singleton_method(:reset_recordings) { false }
      Coverband.configuration.stubs(:trackers).returns([tracker])

      get "/views_tracker/clear_views"

      assert_equal 302, last_response.status
      assert_includes last_response.headers["Location"], "failed"
    end

    test "successful tracker reset is reported as reset" do
      Coverband.configuration.stubs(:web_enable_clear).returns(true)
      tracker = FakeViewsTracker.new(used_keys: {})
      tracker.define_singleton_method(:reset_recordings) { true }
      Coverband.configuration.stubs(:trackers).returns([tracker])

      get "/views_tracker/clear_views"

      assert_equal 302, last_response.status
      refute_includes last_response.headers["Location"], "failed"
    end

    ###
    # A coverage document eviction was logged but never shown: only the tracker
    # tabs surfaced data loss, so the index reported partial numbers as if they
    # were complete.
    ###
    def test_index_surfaces_coverage_data_loss
      loss = Coverband::Storage::Session::DataLoss.new(
        at: Time.now, kind: :eviction, detail: "document disappeared"
      )
      Coverband.configuration.store.stubs(:data_loss).returns(loss)

      get "/"
      assert last_response.ok?
      assert_match(/coverage data was lost at \d{4}-/, last_response.body)
      assert_match(/\(eviction\).*Results before that point are unavailable\./, last_response.body)
    end

    ###
    # Nothing is lost, but nothing is arriving either, and an empty report reads
    # exactly like an app that used nothing.
    ###
    def test_index_reports_work_that_could_not_be_stored
      held = Coverband::Storage::Session::UnwrittenWork.new(deltas: 3, since: Time.now)
      Coverband.configuration.store.stubs(:unwritten).returns(held)

      get "/"
      assert last_response.ok?
      assert_match(/3 coverage reports could not be stored/, last_response.body)
      assert_match(/the oldest since \d{4}-/, last_response.body)
    end

    ###
    # A forfeited repair is not lost data, and the two have to read differently
    # or an operator cannot tell a blip from an eviction.
    ###
    def test_index_words_a_forfeited_repair_differently_from_lost_data
      loss = Coverband::Storage::Session::DataLoss.new(
        at: Time.now, kind: :unconfirmed_dropped, detail: "gave up the retry for 1 deltas"
      )
      Coverband.configuration.store.stubs(:data_loss).returns(loss)

      get "/"
      assert_match(/some coverage data may be undercounted at \d{4}-/, last_response.body)
      assert_match(/Affected only if another process overwrote that write\./, last_response.body)
      refute_match(/was lost/, last_response.body)
    end

    def test_index_says_nothing_when_no_coverage_was_lost
      Coverband.configuration.store.stubs(:data_loss).returns(nil)

      get "/"
      assert last_response.ok?
      refute_match(/data was lost/, last_response.body)
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
