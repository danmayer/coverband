# frozen_string_literal: true

module Coverband
  class Configuration
    attr_accessor :root_paths, :root,
                  :ignore, :additional_files, :verbose,
                  :reporter, :reporting_frequency,
                  :redis_namespace, :redis_ttl,
                  :safe_reload_files, :background_reporting_enabled,
                  :background_reporting_sleep_seconds, :test_env

    attr_writer :logger, :s3_region, :s3_bucket, :s3_access_key_id, :s3_secret_access_key

    def initialize
      reset
    end

    def reset
      @root = Dir.pwd
      @root_paths = []
      @ignore = %w(vendor .erb$ .slim$)
      @additional_files = []
      @reporting_frequency = 0.0
      @verbose = false
      @reporter = 'scov'
      @logger = nil
      @store = nil
      @background_reporting_enabled = true
      @background_reporting_sleep_seconds = 30
      @test_env = nil

      # TODO: should we push these to adapter configs
      @s3_region = nil
      @s3_bucket = nil
      @s3_access_key_id = nil
      @s3_secret_access_key = nil
      @redis_namespace = nil
      @redis_ttl = nil
    end

    def logger
      @logger ||= if defined?(Rails)
                    Rails.logger
                  else
                    Logger.new(STDOUT)
                  end
    end

    def s3_bucket
      @s3_bucket || ENV['AWS_BUCKET']
    end

    def s3_region
      @s3_region || ENV['AWS_REGION']
    end

    def s3_access_key_id
      @s3_access_key_id || ENV['AWS_ACCESS_KEY_ID']
    end

    def s3_secret_access_key
      @s3_secret_access_key || ENV['AWS_SECRET_ACCESS_KEY']
    end

    def store
      @store ||= Coverband::Adapters::RedisStore.new(Redis.new(url: redis_url), redis_store_options)
    end

    def store=(store)
      if store.is_a?(Coverband::Adapters::Base)
        @store = store
      else
        raise 'please pass in an subclass of Coverband::Adapters for supported stores'
      end
    end

    private

    def redis_url
      ENV['COVERBAND_REDIS_URL'] || ENV['REDIS_URL']
    end

    def redis_store_options
      { ttl: Coverband.configuration.redis_ttl,
        redis_namespace: Coverband.configuration.redis_namespace }
    end
  end
end
