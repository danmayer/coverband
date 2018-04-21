# frozen_string_literal: true

module Coverband
  class Configuration
    attr_accessor :redis, :root_paths, :root,
                  :ignore, :additional_files, :percentage, :verbose,
                  :reporter, :startup_delay, :memory_caching,
                  :include_gems, :s3_bucket,
                  :collector, :disable_on_failure_for
    attr_writer :logger

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
      @collector = 'coverage'
      @logger = Logger.new(STDOUT)
      @startup_delay = 0
      @memory_caching = false
      @store = nil
      @disable_on_failure_for = nil
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    def store
      return @store if @store
      raise 'no valid store configured'
    end

    # TODO should I default the store?
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
