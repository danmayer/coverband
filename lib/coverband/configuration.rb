# frozen_string_literal: true

module Coverband
  class Configuration
    attr_accessor :root_paths, :root,
                  :additional_files, :verbose,
                  :reporter, :redis_namespace, :redis_ttl,
                  :background_reporting_enabled,
                  :background_reporting_sleep_seconds, :test_env,
                  :web_enable_clear, :gem_details, :web_debug, :report_on_exit,
                  :simulate_oneshot_lines_coverage, :track_views, :view_tracker,
                  :reporting_wiggle

    attr_writer :logger, :s3_region, :s3_bucket, :s3_access_key_id,
                :s3_secret_access_key, :password
    attr_reader :track_gems, :ignore, :use_oneshot_lines_coverage

    #####
    # TODO: This is is brittle and not a great solution to avoid deploy time
    # actions polluting the 'runtime' metrics
    #
    # * should we skip /bin/rails webpacker:compile ?
    # * Perhaps detect heroku deployment ENV var opposed to tasks?
    #####
    IGNORE_TASKS = ['coverband:clear',
                    'coverband:coverage',
                    'coverband:coverage_server',
                    'coverband:migrate',
                    'assets:precompile',
                    'db:version',
                    'db:create',
                    'db:drop',
                    'db:seed',
                    'db:setup',
                    'db:test:prepare',
                    'db:structure:dump',
                    'db:structure:load',
                    'db:version']

    # Heroku when building assets runs code from a dynamic directory
    # /tmp was added to avoid coverage from /tmp/build directories during
    # heroku asset compilation
    IGNORE_DEFAULTS = %w[vendor/ .erb$ .slim$ /tmp internal:prelude schema.rb]

    # Add in missing files which were never loaded
    # we need to know what all paths to check for unloaded files
    TRACKED_DEFAULT_PATHS = %w[app lib config]

    def initialize
      reset
    end

    def reset
      @root = Dir.pwd
      @root_paths = []
      @ignore = IGNORE_DEFAULTS.dup
      @search_paths = TRACKED_DEFAULT_PATHS.dup
      @additional_files = []
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
      @track_views = false
      @web_debug = false
      @report_on_exit = true
      @use_oneshot_lines_coverage = ENV['ONESHOT'] || false
      @simulate_oneshot_lines_coverage = ENV['SIMULATE_ONESHOT'] || false
      @current_root = nil
      @all_root_paths = nil
      @all_root_patterns = nil
      @password = nil

      # TODO: should we push these to adapter configs
      @s3_region = nil
      @s3_bucket = nil
      @s3_access_key_id = nil
      @s3_secret_access_key = nil
      @redis_namespace = nil
      @redis_ttl = 2_592_000 # in seconds. Default is 30 days.
      @reporting_wiggle = nil
    end

    def logger
      @logger ||= if defined?(Rails.logger) && Rails.logger
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
      raise 'Pass in an instance of Coverband::Adapters' unless store.is_a?(Coverband::Adapters::Base)

      # Default to 5 minutes if using the hash redis store
      # This is a safer default for the high server volumes that need the hash store
      # it should avoid overloading the redis with lots of load
      @background_reporting_sleep_seconds = 300 if store.is_a?(Coverband::Adapters::HashRedisStore)

      @store = store
    end

    ###
    # Search Paths
    ###
    def tracked_search_paths
      "#{Coverband.configuration.current_root}/{#{@search_paths.join(',')}}/**/*.{rb}"
    end

    ###
    # Don't allow the to override defaults
    ###
    def search_paths=(path_array)
      @search_paths = (@search_paths + path_array).uniq
    end

    ###
    # Don't allow the ignore to override things like gem tracking
    ###
    def ignore=(ignored_array)
      @ignore = (@ignore + ignored_array).uniq
    end

    def track_gems=(_value)
      puts "gem tracking is deprecated, setting this will be ignored"
    end

    def current_root
      @current_root ||= File.expand_path(Coverband.configuration.root).freeze
    end

    def all_root_paths
      return @all_root_paths if @all_root_paths

      @all_root_paths = Coverband.configuration.root_paths.dup
      @all_root_paths << "#{Coverband.configuration.current_root}/"
      @all_root_paths
    end

    def all_root_patterns
      @all_root_patterns ||= all_root_paths.map { |path| /^#{path}/ }.freeze
    end

    SKIPPED_SETTINGS = %w[@s3_secret_access_key @store]
    def to_h
      instance_variables
        .each_with_object({}) do |var, hash|
          hash[var.to_s.delete('@')] = instance_variable_get(var) unless SKIPPED_SETTINGS.include?(var.to_s)
        end
    end

    def use_oneshot_lines_coverage=(value)
      raise(Exception, 'One shot line coverage is only available in ruby >= 2.6') unless one_shot_coverage_implemented_in_ruby_version? || !value

      @use_oneshot_lines_coverage = value
    end

    def one_shot_coverage_implemented_in_ruby_version?
      Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.6.0')
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
