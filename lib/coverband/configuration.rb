# frozen_string_literal: true

module Coverband
  ###
  # Configuration parsing and options for the coverband gem.
  ###
  class Configuration
    def self.add_tracker_flag(name, default: false)
      name = name.to_sym
      attr_accessor name
      dynamic_flag_defaults[name] = default
    end

    def self.dynamic_flag_defaults
      @dynamic_flag_defaults ||= {}
    end

    attr_accessor :root_paths, :root,
      :verbose,
      :redis_namespace, :redis_ttl,
      :background_reporting_enabled,
      :test_env, :web_enable_clear, :web_debug, :report_on_exit,
      :use_oneshot_lines_coverage,
      :track_views, :view_tracker, :defer_eager_loading_data,
      :track_routes, :track_redirect_routes, :route_tracker,
      :track_translations, :translations_tracker,
      :track_query_bursts, :query_burst_tracker,
      :query_burst_query_count_threshold, :query_burst_sql_time_threshold_ms,
      :trackers, :csp_policy, :hide_settings,
      :mcp_enabled

    attr_writer :logger, :password, :redis_url,
      :background_reporting_sleep_seconds, :reporting_wiggle,
      :send_deferred_eager_loading_data, :paged_reporting, :mcp_allowed_environments, :mcp_password

    attr_reader :ignore

    HOSTED_SERVICE_REMOVED = "coverband.io is no longer maintained and support for it was removed. " \
      "Delete the setting and configure a store, see Upgrading to 7.0 in the README"

    # Settings removed in 7.0. Assigning one logs how to upgrade rather than
    # raising NoMethodError from the app's config file during boot.
    REMOVED_SETTINGS = {
      reporter: "it has had no effect since Coverband 5.0. Delete the setting",
      api_key: HOSTED_SERVICE_REMOVED,
      service_url: HOSTED_SERVICE_REMOVED,
      coverband_timeout: HOSTED_SERVICE_REMOVED,
      service_dev_mode: HOSTED_SERVICE_REMOVED,
      service_test_mode: HOSTED_SERVICE_REMOVED,
      process_type: HOSTED_SERVICE_REMOVED,
      s3_region: "the S3 report upload was removed earlier and this setting did nothing. Delete the setting",
      s3_bucket: "the S3 report upload was removed earlier and this setting did nothing. Delete the setting",
      s3_access_key_id: "the S3 report upload was removed earlier and this setting did nothing. Delete the setting",
      s3_secret_access_key: "the S3 report upload was removed earlier and this setting did nothing. Delete the setting",
      track_gems: "gem tracking was removed earlier and this setting did nothing. Delete the setting",
      gem_details: "gem tracking was removed earlier and this setting did nothing. Delete the setting",
      simulate_oneshot_lines_coverage: "it had no production effect. Delete the setting"
    }.freeze

    REMOVED_SETTINGS.each do |name, fix|
      define_method(:"#{name}=") do |_value|
        logger.warn "Coverband: config.#{name} was removed in 7.0 and is ignored, #{fix}"
      end
    end

    #####
    # TODO: This is is brittle and not a great solution to avoid deploy time
    # actions polluting the 'runtime' metrics
    #
    # * Perhaps detect heroku deployment ENV var opposed to tasks?
    #####
    IGNORE_TASKS = ["coverband:clear",
      "coverband:coverage",
      "coverband:coverage_server",
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
    IGNORE_DEFAULTS = %w[vendor/ /tmp internal:prelude db/schema.rb] + Collectors::ViewTracker::VIEWS_PATTERNS

    # Add in missing files which were never loaded
    # we need to know what all paths to check for unloaded files
    TRACKED_DEFAULT_PATHS = %w[app lib config]

    def initialize
      reset
    end

    def reset
      @root = Dir.pwd
      @root_paths = []
      @ignore = IGNORE_DEFAULTS.map { |ignore_str| Regexp.new(ignore_str) }
      @search_paths = TRACKED_DEFAULT_PATHS.dup
      @verbose = false
      @logger = nil
      @store = nil
      @background_reporting_enabled = true
      @background_reporting_sleep_seconds = nil
      @defer_eager_loading_data = false
      @send_deferred_eager_loading_data = true
      @test_env = nil
      @web_enable_clear = false
      @track_views = true
      @view_tracker = nil
      @track_routes = false
      @track_redirect_routes = true
      @route_tracker = nil
      @track_translations = false
      @translations_tracker = nil
      @track_query_bursts = false
      @query_burst_tracker = nil
      @query_burst_query_count_threshold = 30
      @query_burst_sql_time_threshold_ms = 100.0
      @web_debug = false
      @report_on_exit = true
      @use_oneshot_lines_coverage = ENV["ONESHOT"] || false
      @current_root = nil
      @all_root_paths = nil
      @all_root_patterns = nil
      @password = nil
      @csp_policy = false
      @hide_settings = false

      # MCP (Model Context Protocol) security settings
      @mcp_enabled = false
      @mcp_password = nil
      @mcp_allowed_environments = %w[development test]

      @redis_url = nil
      @redis_namespace = nil
      @redis_ttl = 2_592_000 # in seconds. Default is 30 days.
      @reporting_wiggle = nil

      @trackers = []
      @registered_trackers = {}
      self.class.dynamic_flag_defaults.each do |name, default|
        instance_variable_set(:"@#{name}", default)
      end
    end

    def railtie!
      unless store.supports_trackers?
        if Coverband::Collectors::TrackerRegistry.registry.any? { |_name, entry| entry.enabled_proc.call(self) }
          logger.info "Coverband: #{store.class.name} does not support tracking, " \
            "view/route/translation/query burst trackers are disabled. " \
            "Coverband::Adapters::ActiveSupportCacheStore supports tracking on any ActiveSupport::Cache store."
        end
        return
      end

      Coverband::Collectors::TrackerRegistry.each do |entry|
        next unless entry.enabled_proc.call(self)

        tracker = build_tracker(entry)
        setter = :"#{entry.name}="
        public_send(setter, tracker) if respond_to?(setter)
        registered_trackers[entry.name] = tracker
        trackers << tracker
      end
      trackers.each { |tracker| tracker.railtie! }
    rescue *Coverband.redis_connection_errors => e
      Coverband.configuration.logger.info "Redis is not available (#{e}), Coverband not configured"
      Coverband.configuration.logger.info "If this is a setup task like assets:precompile feel free to ignore"
    end

    def logger
      @logger ||= if defined?(Rails.logger) && Rails.logger
        Rails.logger
      else
        Logger.new($stdout)
      end
    end

    # Alias for backward compatibility - track_key uses :routes_tracker symbol
    def routes_tracker
      route_tracker
    end

    # Look up an initialized tracker by its registered name. Bundled trackers
    # also have their own accessor, trackers registered by an app or gem only
    # have this.
    def tracker_for(name)
      registered_trackers[name.to_sym]
    end

    def password
      @password || ENV["COVERBAND_PASSWORD"]
    end

    def mcp_enabled?
      # MCP is disabled by default and explicitly controlled
      return false unless @mcp_enabled

      # Check if current environment is allowed
      current_env = (defined?(Rails) && Rails.respond_to?(:env) && Rails.env) ||
        ENV["RAILS_ENV"] ||
        ENV["RACK_ENV"] ||
        "development"

      mcp_allowed_environments.include?(current_env.to_s)
    end

    def mcp_password
      @mcp_password || ENV["COVERBAND_MCP_PASSWORD"]
    end

    def mcp_allowed_environments
      @mcp_allowed_environments || %w[development test]
    end

    # The adjustments here protect the store from being overloaded
    # the tradeoff being the delay in when reporting data is available
    # if running your own redis increasing this number reduces load on the redis CPU
    def background_reporting_sleep_seconds
      @background_reporting_sleep_seconds ||= if store.is_a?(Coverband::Adapters::ActiveSupportCacheStore)
        # every report rewrites a whole document, and a cache backed store is
        # the one most likely to be shared with the host application
        600
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
      @store ||= if !Coverband.redis_available?
        logger.warn "Coverband: no store configured and the redis gem is not installed, so coverage is not being recorded"
        logger.warn "Coverband: add `gem \"redis\"` to your Gemfile to use the default Redis store, or configure one: config.store = Coverband::Adapters::ActiveSupportCacheStore.new { Rails.cache }"
        require "coverband/adapters/null_store"
        Coverband::Adapters::NullStore.new
      else
        begin
          # Redis gem automatically enables TLS when the scheme is 'rediss://'
          # For serverless ElastiCache or other TLS-required Redis instances, use:
          #   REDIS_URL=rediss://your-endpoint:6379
          Coverband::Adapters::RedisStore.new(Redis.new(url: redis_url), redis_store_options)
        rescue *Coverband.redis_connection_errors => error
          logger.info "Redis is not available (#{error}), defaulting to NullStore"
          logger.info "If this is intended, please explicitly configure your store: config.store = Coverband::Adapters::FileStore.new('log/coverage')"
          require "coverband/adapters/null_store"
          Coverband::Adapters::NullStore.new
        end
      end
    end

    def store=(store)
      raise "Pass in an instance of Coverband::Adapters" unless store.is_a?(Coverband::Adapters::Base)

      @store = store
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
      ignored_array = ignored_array.map { |ignore_str| Regexp.new(ignore_str) }
      @ignore |= ignored_array
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

    SKIPPED_SETTINGS = %w[@store @password @mcp_password]
    def to_h
      instance_variables
        .each_with_object({}) do |var, hash|
          hash[var.to_s.delete("@")] = instance_variable_get(var) unless SKIPPED_SETTINGS.include?(var.to_s)
        end
    end

    def redis_url
      @redis_url ||= ENV["COVERBAND_REDIS_URL"] || ENV["REDIS_URL"]
    end

    def coverband_env
      ENV["RACK_ENV"] || ENV["RAILS_ENV"] || ((defined?(Rails) && Rails.respond_to?(:env)) ? Rails.env : "unknown")
    end

    def defer_eager_loading_data?
      @defer_eager_loading_data
    end

    def send_deferred_eager_loading_data?
      @send_deferred_eager_loading_data
    end

    def paged_reporting
      !!@paged_reporting
    end

    private

    def registered_trackers
      @registered_trackers ||= {}
    end

    def build_tracker(entry)
      tracker = if entry.tracker_class.respond_to?(:call)
        entry.tracker_class.call
      else
        entry.tracker_class.new
      end
      Coverband::Collectors::TrackerRegistry.validate_report_route!(entry.name, tracker.class)
      tracker
    end

    def redis_store_options
      {ttl: Coverband.configuration.redis_ttl,
       redis_namespace: Coverband.configuration.redis_namespace}
    end
  end
end
