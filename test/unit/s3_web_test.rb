# frozen_string_literal: true

require File.expand_path('../test_helper', File.dirname(__FILE__))
require 'aws-sdk'
require File.expand_path('../../lib/coverband/s3_web', File.dirname(__FILE__))
require 'rack/test'

ENV['RACK_ENV'] = 'test'

module Coverband
  class S3WebTest < Test::Unit::TestCase
    include Rack::Test::Methods

    def app
      Coverband::S3Web
    end

    # TODO add tests for all endpoints
    test 'renders index content' do
      get '/'
      assert last_response.ok?
      assert_match 'Coverband Web Admin Index', last_response.body
    end

    test 'renders show content' do
      Coverband.configuration.s3_bucket = 'coverage-bucket'
      s3 = mock('s3')
      Aws::S3::Client.expects(:new).returns(s3)
      s3.expects(:get_object).with(bucket: 'coverage-bucket', key: 'coverband/index.html').returns mock('response', body: mock('body', read: 'content'))
      get '/show'
      assert last_response.ok?
      assert_equal 'content', last_response.body
    end
  end
end
