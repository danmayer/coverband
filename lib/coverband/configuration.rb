module Coverband
  class Configuration
     
    attr_accessor :redis, :coverage_baseline, :root_paths, :root, 
                  :ignore, :percentage, :verbose, :reporter, :stats,
                  :logger, :startup_delay, :baseline_file, :trace_point_events, 
                  :include_gems, :memory_caching, :s3_bucket, :coverage_file, :store

    def initialize
      @root = Dir.pwd
      @redis = nil
      @stats = nil
      @coverage_baseline = {}
      @baseline_file = './tmp/coverband_baseline.json'
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
