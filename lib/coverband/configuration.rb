# frozen_string_literal: true

module Coverband
  class Configuration
    attr_accessor :redis, :root_paths, :root,
                  :ignore, :additional_files, :verbose,
                  :reporter, :memory_caching, :reporting_frequency,
                  :include_gems, :collector, :disable_on_failure_for,
                  :redis_namespace, :redis_ttl,
                  :safe_reload_files

    attr_writer :logger, :s3_region, :s3_bucket, :s3_access_key_id, :s3_secret_access_key

    def initialize
      @root = Dir.pwd
      @root_paths = []
      @ignore = []
      @additional_files = []
      @reporting_frequency = 0.0
      @verbose = false
      @reporter = 'scov'
      @collector = 'coverage'
      @logger = Logger.new(STDOUT)
      @memory_caching = false
      @store = nil

      # TODO: should we push these to adapter configs
      @s3_region = nil
      @s3_bucket = nil
      @s3_access_key_id = nil
      @s3_secret_access_key = nil
      @redis_namespace = nil
      @redis_ttl = nil
    end

    def logger
      @logger ||= Logger.new(STDOUT)
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
      return @store if @store
      raise 'no valid store configured'
    end

    def store=(store)
      if store.is_a?(Coverband::Adapters::Base)
        @store = store
      elsif defined?(Redis) && redis && redis.is_a?(Redis)
        @store = Coverband::Adapters::RedisStore.new(redis, ttl: Coverband.configuration.redis_ttl,
                                                            redis_namespace: Coverband.configuration.redis_namespace)
      elsif store.is_a?(String)
        @store = Coverband::Adapters::FileStore.new(store)
      end
    end
  end
end
