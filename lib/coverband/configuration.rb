module Coverband
  class Configuration
      attr_accessor :redis 
      attr_accessor :redis_ttl 
      attr_accessor :redis_namespace 
      attr_accessor :root_paths 
      attr_accessor :root
      attr_accessor :ignore 
      attr_accessor :additional_files 
      attr_accessor :percentage 
      attr_accessor :verbose 
      attr_accessor :reporter
      attr_accessor :stats 
      attr_accessor :logger 
      attr_accessor :startup_delay 
      attr_accessor :trace_point_events
      attr_accessor :include_gems 
      attr_accessor :memory_caching 
      attr_accessor :max_caching 
      attr_accessor :s3_bucket 
      attr_accessor :coverage_file 
      attr_accessor :store
      attr_accessor :disable_on_failure_for

    # deprecated, but leaving to allow old configs to 'just work'
    # remove for 2.0
    attr_accessor :coverage_baseline

    def initialize
      @root                   = Dir.pwd
      @redis                  = nil
      @redis_ttl              = nil
      @redis_namespace        = nil
      @stats                  = nil
      @root_paths             = []
      @ignore                 = []
      @additional_files       = []
      @include_gems           = false
      @percentage             = 0.0
      @verbose                = false
      @reporter               = 'scov'
      @logger                 = Logger.new(STDOUT)
      @startup_delay          = 0
      @trace_point_events     = [:line]
      @memory_caching         = false
      @max_caching            = nil
      @coverage_file          = nil
      @store                  = nil
      @disable_on_failure_for = nil
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    #TODO considering removing @redis / @coveragefile and have user set store directly
    def store
      return @store if @store
      if redis
        @store = Coverband::Adapters::RedisStore.new(redis, ttl: Coverband.configuration.redis_ttl, redis_namespace: Coverband.configuration.redis_namespace)
      elsif Coverband.configuration.coverage_file
        @store = Coverband::Adapters::FileStore.new(coverage_file)
      end
      @store
    end

  end
end
