# frozen_string_literal: true

module Coverband
  module Utils
    ###
    # TODO: this is currently a html report writer
    # this should support writing coverage the current method should be fine
    # to write every report to S3 and sum them later or use the 2 pass
    # method we do for redis if in a background thread
    ###
    class S3Report
      def self.instance
        s3_options = {
          region: Coverband.configuration.s3_region,
          access_key_id: Coverband.configuration.s3_access_key_id,
          secret_access_key: Coverband.configuration.s3_secret_access_key
        }
        new(Coverband.configuration.s3_bucket, s3_options)
      end

      def initialize(bucket_name, options = {})
        @bucket_name = bucket_name
        @region = options[:region]
        @access_key_id = options[:access_key_id]
        @secret_access_key = options[:secret_access_key]
        begin
          require 'aws-sdk-s3'
        rescue StandardError
          err_msg = 'coverband requires aws-sdk in order use S3Report.'
          Coverband.configuration.logger.error err_msg
          return
        end
      end

      def persist!
        if defined?(Aws)
          object.put(body: coverage_content)
        else
          object.write(coverage_content)
        end
      end

      def retrieve
        if defined?(Aws)
          s3_client.get_object(bucket: Coverband.configuration.s3_bucket,
                               key: 'coverband/index.html').body.read
        else
          object.read
        end
      end

      private

      def coverage_content
        version = Coverband::VERSION
        File.read("#{Coverband.configuration.root}/coverage/index.html").gsub("./assets/#{version}/", '')
      end

      def object
        if defined?(Aws)
          bucket.object('coverband/index.html')
        else
          bucket.objects['coverband/index.html']
        end
      end

      def client_options
        {
          region: @region,
          access_key_id: @access_key_id,
          secret_access_key: @secret_access_key
        }
      end

      def s3_client
        if defined?(Aws)
          # AWS SDK v2
          Aws::S3::Client.new(client_options)
        else
          # AWS SDK v1
          AWS::S3::Client.new(client_options)
        end
      end

      def s3
        resource_options = { client: s3_client }
        resource_options = {} if client_options.values.any?(&:nil?)
        if defined?(Aws)
          # AWS SDK v2
          Aws::S3::Resource.new(resource_options)
        else
          # AWS SDK v1
          AWS::S3.new(resource_options)
        end
      end

      def bucket
        if defined?(Aws)
          s3.bucket(@bucket_name)
        else
          s3.buckets[@bucket_name]
        end
      end
    end
  end
end
