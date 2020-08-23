# frozen_string_literal: true

module Coverband
  class Configuration
    attr_accessor :root_paths, :root,
      :verbose,
      :reporter, :redis_namespace, :redis_ttl,
      :background_reporting_enabled,
      :test_env, :web_enable_clear, :gem_details, :web_debug, :report_on_exit,
      :simulate_oneshot_lines_coverage,
      :view_tracker
    attr_writer :logger, :s3_region, :s3_bucket, :s3_access_key_id,
      :s3_secret_access_key, :password, :api_key, :service_url, :coverband_timeout, :service_dev_mode,
      :service_test_mode, :process_type, :track_views, :redis_url,
      :background_reporting_sleep_seconds, :reporting_wiggle

    attr_reader :track_gems, :ignore, :use_oneshot_lines_coverage

    #####
    # TODO: This is is brittle and not a great solution to avoid deploy time
    # actions polluting the 'runtime' metrics
    #
    # * Perhaps detect heroku deployment ENV var opposed to tasks?
    #####
    IGNORE_TASKS = ["coverband:clear",
                    "coverband:coverage",
                    "coverband:coverage_server",
                    "coverband:migrate",
                    "assets:precompile",
                    "webpacker:compile",
                    "db:version",
                    "db:create",
                    "db:drop",
                    "db:seed",
                    "db:setup",
                    "db:test:prepare",
                    "db:structure:dump",
                    "db:structure:load",
                    "db:version"]

    # Heroku when building assets runs code from a dynamic directory
    # /tmp was added to avoid coverage from /tmp/build directories during
    # heroku asset compilation
    IGNORE_DEFAULTS = %w[vendor/ .erb$ .slim$ /tmp internal:prelude db/schema.rb]

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
      @verbose = false
      @reporter = "scov"
      @logger = nil
      @store = nil
      @background_reporting_enabled = true
      @background_reporting_sleep_seconds = nil
      @test_env = nil
      @web_enable_clear = false
      @track_views = true
      @view_tracker = nil
      @web_debug = false
      @report_on_exit = true
      @use_oneshot_lines_coverage = ENV["ONESHOT"] || false
      @simulate_oneshot_lines_coverage = ENV["SIMULATE_ONESHOT"] || false
      @current_root = nil
      @all_root_paths = nil
      @all_root_patterns = nil
      @password = nil

      # coverband service settings
      @api_key = nil
      @service_url = nil
      @coverband_timeout = nil
      @service_dev_mode = nil
      @service_test_mode = nil
      @proces_type = nil

      @redis_url = nil
      @redis_namespace = nil
      @redis_ttl = 2_592_000 # in seconds. Default is 30 days.
      @reporting_wiggle = nil

      # TODO: these are deprecated
      @s3_region = nil
      @s3_bucket = nil
      @s3_access_key_id = nil
      @s3_secret_access_key = nil
      @track_gems = false
      @gem_details = false
    end

    def logger
      @logger ||= if defined?(Rails.logger) && Rails.logger
        Rails.logger
      else
        Logger.new(STDOUT)
      end
    end

    def password
      @password || ENV["COVERBAND_PASSWORD"]
    end

    # The adjustments here either protect the redis or service from being overloaded
    # the tradeoff being the delay in when reporting data is available
    # if running your own redis increasing this number reduces load on the redis CPU
    def background_reporting_sleep_seconds
      @background_reporting_sleep_seconds ||= if service?
        # default to 10m for service
        Coverband.configuration.coverband_env == "production" ? 600 : 60
      elsif store.is_a?(Coverband::Adapters::HashRedisStore)
        # Default to 5 minutes if using the hash redis store
        300
      else
        60
      end
    end

    def reporting_wiggle
      @reporting_wiggle ||= 30
    end

    def store
      @store ||= if service?
        raise "invalid configuration: unclear default store coverband expects either api_key or redis_url" if redis_url
        require "coverband/adapters/web_service_store"
        Coverband::Adapters::WebServiceStore.new(service_url)
      else
        Coverband::Adapters::RedisStore.new(Redis.new(url: redis_url), redis_store_options)
      end
    end

    def store=(store)
      raise "Pass in an instance of Coverband::Adapters" unless store.is_a?(Coverband::Adapters::Base)
      raise "invalid configuration: only coverband service expects an API Key" if api_key && !store.is_a?(Coverband::Adapters::WebServiceStore)
      raise "invalid configuration: coverband service shouldn't have redis url set" if redis_url && store.is_a?(Coverband::Adapters::WebServiceStore)

      @store = store
    end

    def track_views
      @track_views ||= service_disabled_dev_test_env? ? false : true
    end

    ###
    # Search Paths
    ###
    def tracked_search_paths
      "#{Coverband.configuration.current_root}/{#{@search_paths.join(",")}}/**/*.{rb}"
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

    SKIPPED_SETTINGS = %w[@s3_secret_access_key @store @api_key @password]
    def to_h
      instance_variables
        .each_with_object({}) do |var, hash|
          hash[var.to_s.delete("@")] = instance_variable_get(var) unless SKIPPED_SETTINGS.include?(var.to_s)
        end
    end

    def use_oneshot_lines_coverage=(value)
      raise(StandardError, "One shot line coverage is only available in ruby >= 2.6") unless one_shot_coverage_implemented_in_ruby_version? || !value

      @use_oneshot_lines_coverage = value
    end

    def one_shot_coverage_implemented_in_ruby_version?
      Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.6.0")
    end

    def redis_url
      @redis_url ||= ENV["COVERBAND_REDIS_URL"] || ENV["REDIS_URL"]
    end

    def api_key
      @api_key ||= ENV["COVERBAND_API_KEY"]
    end

    def service_url
      @service_url ||= ENV["COVERBAND_URL"] || "https://coverband.io"
    end

    def coverband_env
      ENV["RACK_ENV"] || ENV["RAILS_ENV"] || (defined?(Rails) && Rails.respond_to?(:env) ? Rails.env : "unknown")
    end

    def coverband_timeout
      @coverband_timeout ||= coverband_env == "development" ? 5 : 2
    end

    def service_dev_mode
      @service_dev_mode ||= ENV["COVERBAND_ENABLE_DEV_MODE"] || false
    end

    def service_test_mode
      @service_dev_mode ||= ENV["COVERBAND_ENABLE_TEST_MODE"] || false
    end

    def process_type
      @process_type ||= ENV["PROCESS_TYPE"] || "unknown"
    end

    def service?
      Coverband.coverband_service? || !api_key.nil?
    end

    def service_disabled_dev_test_env?
      (coverband_env == "test" && !Coverband.configuration.service_test_mode) ||
        (coverband_env == "development" && !Coverband.configuration.service_dev_mode)
    end

    def s3_bucket
      puts "deprecated, s3 is no longer support"
    end

    def s3_region
      puts "deprecated, s3 is no longer support"
    end

    def s3_access_key_id
      puts "deprecated, s3 is no longer support"
    end

    def s3_secret_access_key
      puts "deprecated, s3 is no longer support"
    end

    def track_gems=(_value)
      puts "gem tracking is deprecated, setting this will be ignored"
    end

    private

    def redis_store_options
      {ttl: Coverband.configuration.redis_ttl,
       redis_namespace: Coverband.configuration.redis_namespace}
    end
  end
end
