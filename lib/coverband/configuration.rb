# frozen_string_literal: true

module Coverband
  class Configuration
    attr_accessor :root_paths, :root,
                  :ignore, :additional_files, :verbose,
                  :reporter, :reporting_frequency,
                  :redis_namespace, :redis_ttl,
                  :safe_reload_files, :background_reporting_enabled,
                  :background_reporting_sleep_seconds, :test_env,
                  :web_enable_clear, :gem_details

    attr_writer :logger, :s3_region, :s3_bucket, :s3_access_key_id, :s3_secret_access_key
    attr_reader :track_gems

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
      @web_enable_clear = false
      @track_gems = false
      @gem_details = false
      @groups = {}

      # TODO: should we push these to adapter configs
      @s3_region = nil
      @s3_bucket = nil
      @s3_access_key_id = nil
      @s3_secret_access_key = nil
      @redis_namespace = nil
      @redis_ttl = nil
    end

    def logger
      @logger ||= if defined?(Rails.logger)
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

    def track_gems=(value)
      @track_gems = value
      return unless @track_gems
      add_group('App', root)
      # TODO: rework support for multiple gem paths
      # currently this supports GEM_HOME (which should be first path)
      # but various gem managers setup multiple gem paths
      # gem_paths.each_with_index do |path, index|
      #   add_group("gems_#{index}", path)
      # end
      add_group('Gems', gem_paths.first)
    end

    #
    # Returns the configured groups. Add groups using SimpleCov.add_group
    #
    def groups
      @groups ||= {}
    end

    #
    # Define a group for files. Works similar to add_filter, only that the first
    # argument is the desired group name and files PASSING the filter end up in the group
    # (while filters exclude when the filter is applicable).
    #
    def add_group(group_name, filter_argument = nil)
      groups[group_name] = filter_argument
    end

    def gem_paths
      # notes ignore any paths that aren't on this system, resolves
      # bug related to multiple ruby version managers / bad dot files
      Gem::PathSupport.new(ENV).path.select { |path| File.exist?(path) }
    end

    SKIPPED_SETTINGS = %w[@s3_secret_access_key @store]
    def to_h
      hash = {}
      instance_variables.each do |var|
        hash[var.to_s.delete('@')] = instance_variable_get(var) unless SKIPPED_SETTINGS.include?(var.to_s)
      end
      hash['gem_paths'] = gem_paths
      hash
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
