# frozen_string_literal: true

module Coverband
  class Configuration
    attr_accessor :root_paths, :root,
                  :ignore, :additional_files, :verbose,
                  :reporter, :reporting_frequency,
                  :redis_namespace, :redis_ttl,
                  :safe_reload_files, :background_reporting_enabled,
                  :background_reporting_sleep_seconds, :test_env,
                  :web_enable_clear, :gem_details, :web_debug

    attr_writer :logger, :s3_region, :s3_bucket, :s3_access_key_id, :s3_secret_access_key, :password
    attr_reader :track_gems

    def initialize
      reset
    end

    def reset
      @root = Dir.pwd
      @root_paths = []
      # Heroku when building assets runs code from a dynamic directory
      # /tmp was added to avoid coverage from /tmp/build directories during
      # heroku asset compilation
      @ignore = %w[vendor .erb$ .slim$ /tmp]
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
      @web_debug = false
      @password = nil

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

    def password
      @password || ENV['COVERBAND_PASSWORD']
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
      # by default we ignore vendor where many deployments put gems
      # we will remove this default if track_gems is set
      @ignore.delete('vendor')
      # while we want to allow vendored gems we don't want to track vendored ruby STDLIB
      @ignore << 'vendor/ruby-*'
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

    def current_root
      File.expand_path(Coverband.configuration.root)
    end

    def all_root_paths
      roots = Coverband.configuration.root_paths.dup
      roots += Coverband.configuration.gem_paths.dup if Coverband.configuration.track_gems
      roots << "#{Coverband.configuration.current_root}/"
      roots
    end

    SKIPPED_SETTINGS = %w(@s3_secret_access_key @store)
    def to_h
      instance_variables
        .each_with_object('gem_paths': gem_paths) do |var, hash|
          hash[var.to_s.delete('@')] = instance_variable_get(var) unless SKIPPED_SETTINGS.include?(var.to_s)
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
