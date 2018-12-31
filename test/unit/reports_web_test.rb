# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))
require 'aws-sdk-s3'
require File.expand_path('../../lib/coverband/reporters/web', File.dirname(__FILE__))
require 'rack/test'

ENV['RACK_ENV'] = 'test'

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.2.0')
  module Coverband
    class WebTest < Minitest::Test
      include Rack::Test::Methods

      def app
        Coverband::Reporters::Web.new
      end

      def teardown
        super
        Coverband.configuration.s3_bucket = nil
      end

      test 'renders index content' do
        get '/'
        assert last_response.ok?
        assert_match 'Coverband Admin', last_response.body
      end

      test 'renders 404' do
        get '/show'
        assert last_response.not_found?
        assert_equal '404 error!', last_response.body
      end

      test 'clears coverband' do
        post '/clear'
        assert_equal 301, last_response.status
      end

      test 'collect_coverage' do
        post '/collect_coverage'
        assert_equal 301, last_response.status
      end

      test 'reload_files' do
        post '/reload_files'
        assert_equal 301, last_response.status
      end
    end
  end
end
