module Coverband
  class Configuration
     
    attr_accessor :redis, :root_paths, :root,
                  :ignore, :percentage, :verbose, :reporter, :stats,
                  :logger, :startup_delay, :trace_point_events,
                  :include_gems, :memory_caching, :s3_bucket, :coverage_file, :store

    # deprecated, but leaving to allow old configs to 'just work'
    # remove for 2.0
    attr_accessor :coverage_baseline

    def initialize
      @root = Dir.pwd
      @redis = nil
      @stats = nil
      @root_paths = []
      @ignore = []
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
