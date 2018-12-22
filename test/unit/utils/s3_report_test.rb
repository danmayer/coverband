require File.expand_path('../../test_helper', File.dirname(__FILE__))
require 'aws-sdk'

module Coverband
  class S3ReportTest < Minitest::Test
    def html_version
      Coverband::VERSION
    end

    test 'it writes the coverage report to s3' do
      if defined?(Aws::S3::Resource)
        # AWS v2
        s3 = mock('s3_resource')
        bucket = mock('bucket')
        object = mock('object')
        s3.expects(:bucket).with('coverage-bucket').returns(bucket)
        bucket.expects(:object).with('coverband/index.html').returns(object)
        File.expects(:read).at_least(0).returns("content ./assets/#{html_version}/")
        object.expects(:put).with(body: 'content ')
        Aws::S3::Resource.expects(:new).returns(s3)
      else
        # AWS v1
        object = mock('object')
        object.expects(:write).with('content ')
        bucket = mock('bucket')
        bucket.expects(:objects).returns('coverband/index.html' => object)
        local_s3 = mock('s3_resource')
        local_s3.expects(:buckets).returns('coverage-bucket' => bucket)
        File.expects(:read).at_least(0).returns("content ./assets/#{html_version}/")
        AWS::S3::Client.expects(:new).returns(nil)
        AWS::S3.expects(:new).returns(local_s3)
      end

      s3_options = {
        region: 'us-west-1',
        access_key_id: '',
        secret_access_key: ''
      }
      Coverband::Utils::S3Report.new('coverage-bucket', s3_options).persist!
    end
  end
end
