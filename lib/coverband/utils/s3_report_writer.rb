# frozen_string_literal: true

module Coverband
  module Utils
    ###
    # TODO: this is currently a html report writer
    # this should support writing coverage the current method should be fine
    # to write every report to S3 and sum them later or use the 2 pass
    # method we do for redis if in a background thread
    ###
    class S3ReportWriter
      def initialize(bucket_name, options = {})
        @bucket_name = bucket_name
        @region = options[:region]
        @access_key_id = options[:access_key_id]
        @secret_access_key = options[:secret_access_key]
        begin
          require 'aws-sdk'
        rescue StandardError
          err_msg = 'coverband requires aws-sdk in order use S3ReportWriter.'
          Coverband.configuration.logger.error err_msg
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
        client_options = {
          region: @region,
          access_key_id: @access_key_id,
          secret_access_key: @secret_access_key
        }
        resource_options = { client: Aws::S3::Client.new(client_options) }
        resource_options = {} if client_options.values.any?(&:nil?)
        Aws::S3::Resource.new(resource_options)
      end

      def bucket
        s3.bucket(@bucket_name)
      end
    end
  end
end
