module Coverband
  class Configuration

    attr_accessor :redis, :root_paths, :root,
                  :ignore, :additional_files, :percentage, :verbose, :reporter,
                  :stats, :logger, :startup_delay, :trace_point_events,
                  :include_gems, :memory_caching, :coverage_file, :store, :disable_on_failure_for,
                  :s3_bucket, :s3_region, :s3_access_key_id, :s3_secret_access_key

    # deprecated, but leaving to allow old configs to 'just work'
    # remove for 2.0
    attr_accessor :coverage_baseline

    def initialize
      @root = Dir.pwd
      @redis = nil
      @stats = nil
      @root_paths = []
      @ignore = []
      @additional_files = []
      @include_gems = false
      @percentage = 0.0
      @verbose = false
      @reporter = 'scov'
      @logger = Logger.new(STDOUT)
      @startup_delay = 0
      @trace_point_events = [:line]
      @memory_caching = false
      @coverage_file = nil
      @store = nil
      @disable_on_failure_for = nil
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    #TODO considering removing @redis / @coveragefile and have user set store directly
    def store
      return @store if @store
      if redis
        @store = Coverband::Adapters::RedisStore.new(redis)
      elsif Coverband.configuration.coverage_file
        @store = Coverband::Adapters::FileStore.new(coverage_file)
      end
      @store
    end

  end
end
