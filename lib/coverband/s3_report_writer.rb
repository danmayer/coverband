# frozen_string_literal: true

class S3ReportWriter
  def initialize(bucket_name)
    @bucket_name = bucket_name
    begin
      require 'aws-sdk'
    rescue StandardError
      Coverband.configuration.logger.error "coverband requires 'aws-sdk' in order use S3ReportWriter."
      return
    end
  end

  def persist!
    object.put(body: coverage_content)
  end

  private

  def coverage_content
    version = Gem::Specification.find_by_name('simplecov-html').version.version
    File.read("#{SimpleCov.coverage_dir}/index.html").gsub("./assets/#{version}/", '')
  rescue StandardError
    File.read("#{SimpleCov.coverage_dir}/index.html").to_s.gsub('./assets/0.10.1/', '')
  end

  def object
    bucket.object('coverband/index.html')
  end

  def s3
    Aws::S3::Resource.new
  end

  def bucket
    s3.bucket(@bucket_name)
  end
end
