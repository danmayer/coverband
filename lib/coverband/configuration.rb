# frozen_string_literal: true

module Coverband
  class Configuration
    attr_accessor :redis, :root_paths, :root,
                  :ignore, :additional_files, :percentage, :verbose,
                  :reporter, :startup_delay, :memory_caching,
                  :include_gems, :s3_bucket,
                  :collector, :disable_on_failure_for
    attr_writer :logger, :s3_region, :s3_bucket, :s3_access_key_id, :s3_secret_access_key

    def initialize
      @root = Dir.pwd
      @redis = nil
      @root_paths = []
      @ignore = []
      @additional_files = []
      @include_gems = false
      @percentage = 0.0
      @verbose = false
      @reporter = 'scov'
      if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3.0')
        @collector = 'trace'
      else
        @collector = 'coverage'
      end
      @logger = Logger.new(STDOUT)
      @startup_delay = 0
      @memory_caching = false
      @store = nil
      @disable_on_failure_for = nil
      @s3_region = nil
      @s3_bucket = nil
      @s3_access_key_id = nil
      @s3_secret_access_key = nil
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
      elsif defined?(Redis) && store.is_a?(Redis)
        @store = Coverband::Adapters::RedisStore.new(redis)
      elsif store.is_a?(String)
        @store = Coverband::Adapters::FileStore.new(coverage_file)
      end
    end
  end
end
