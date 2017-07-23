require File.expand_path('../test_helper', File.dirname(__FILE__))
require 'aws-sdk'

module Coverband

  class S3ReportWriterTest < Test::Unit::TestCase

    def html_version
     begin
      "#{Gem::Specification.find_by_name('simplecov-html').version.version}"
    rescue
      File.read("#{SimpleCov.coverage_dir}/index.html").gsub("./assets/0.10.1/", '')
          end
    end
    
    test 'it writes the coverage report to s3' do
      s3 = mock('s3_resource')
      bucket = mock('bucket')
      object = mock('object')
      s3.expects(:bucket).with('coverage-bucket').returns(bucket)
      bucket.expects(:object).with('coverband/index.html').returns(object)
      File.expects(:read).at_least(0) { "content ./assets/#{html_version}/" }
      File.expects(:read).with("#{SimpleCov.coverage_dir}/index.html").returns("content ./assets/#{html_version}/")
      object.expects(:put).with(body: 'content ')
      Aws::S3::Resource.expects(:new).returns(s3)
      S3ReportWriter.new('coverage-bucket').persist!
    end

  end

end
