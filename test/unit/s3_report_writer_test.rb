require File.expand_path('../test_helper', File.dirname(__FILE__))

module Coverband

  class S3ReportWriterTest < Test::Unit::TestCase

    test 'it writes the coverage report to s3' do
      s3 = mock('s3_resource')
      bucket = mock('bucket')
      object = mock('object')
      s3.expects(:bucket).with('coverage-bucket').returns(bucket)
      bucket.expects(:object).with('coverband/index.html').returns(object)
      File.expects(:read).with("#{SimpleCov.coverage_dir}/index.html").returns("content ./assets/#{Gem::Specification.find_by_name('simplecov-html').version.version}/")
      object.expects(:put).with(body: 'content ')
      Aws::S3::Resource.expects(:new).returns(s3)
      S3ReportWriter.new('coverage-bucket').persist!
    end

  end

end
