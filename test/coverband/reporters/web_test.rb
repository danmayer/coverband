# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require File.expand_path("../../../lib/coverband/reporters/web", File.dirname(__FILE__))
require "rack/test"

ENV["RACK_ENV"] = "test"

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.2.0")
  module Coverband
    class WebTest < Minitest::Test
      include Rack::Test::Methods

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
        assert_equal 301, last_response.status
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
end
