# frozen_string_literal: true

require "logger"
require "json"
require "redis"
require "coverband/version"
require "coverband/at_exit"
require "coverband/utils/relative_file_converter"
require "coverband/utils/absolute_file_converter"
require "coverband/adapters/base"
require "coverband/adapters/redis_store"
require "coverband/adapters/hash_redis_store"
require "coverband/adapters/file_store"
require "coverband/adapters/stdout_store"
require "coverband/adapters/null_store"
require "coverband/adapters/memcached_store"
require "coverband/utils/file_hasher"
require "coverband/collectors/coverage"
require "coverband/collectors/abstract_tracker"
require "coverband/collectors/view_tracker"
require "coverband/collectors/view_tracker_service"
require "coverband/collectors/route_tracker"
require "coverband/collectors/translation_tracker"
require "coverband/reporters/base"
require "coverband/reporters/console_report"
require "coverband/integrations/background"
require "coverband/integrations/background_middleware"
require "coverband/integrations/rack_server_check"
require "coverband/configuration"

Coverband::Adapters::RedisStore = Coverband::Adapters::HashRedisStore if ENV["COVERBAND_HASH_REDIS_STORE"]

module Coverband
  @@configured = false
  SERVICE_CONFIG = "./config/coverband_service.rb"
  CONFIG_FILE = "./config/coverband.rb"
  RUNTIME_TYPE = :runtime
  EAGER_TYPE = :eager_loading
  MERGED_TYPE = :merged
  TYPES = [RUNTIME_TYPE, EAGER_TYPE]
  ALL_TYPES = TYPES + [:merged]

  def self.configure(file = nil)
    configuration_file = file || ENV["COVERBAND_CONFIG"]
    if configuration_file.nil?
      configuration_file = coverband_service? ? SERVICE_CONFIG : CONFIG_FILE
    end

    configuration
    if block_given?
      yield(configuration)
    elsif File.exist?(configuration_file)
      load configuration_file
    else
      configuration.logger.debug("using default configuration") if Coverband.configuration.verbose
    end
    @@configured = true
    coverage_instance.reset_instance
  end

  def self.coverband_service?
    !!File.exist?(SERVICE_CONFIG)
  end

  def self.configured?
    @@configured
  end

  def self.report_coverage
    coverage_instance.report_coverage
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.start
    Coverband::Collectors::Coverage.instance
    # TODO: Railtie sets up at_exit after forks, via middleware, perhaps this should be
    # added if not rails or if rails but not rackserverrunning
    AtExit.register unless tasks_to_ignore?
    Background.start if configuration.background_reporting_enabled && !RackServerCheck.running? && !tasks_to_ignore?
  end

  def self.tasks_to_ignore?
    defined?(Rake) &&
      Rake.respond_to?(:application) &&
      (Rake&.application&.top_level_tasks || []).any? { |task| Coverband::Configuration::IGNORE_TASKS.include?(task) }
  end

  def self.eager_loading_coverage!
    coverage_instance.eager_loading!
  end

  def self.eager_loading_coverage(...)
    coverage_instance.eager_loading(...)
  end

  def self.runtime_coverage!
    coverage_instance.runtime!
  end

  # Track a key with the specified tracker.
  # @param tracker_type [Symbol] The type of tracker to use (e.g., :view_tracker, :translations_tracker, :routes_tracker)
  # @param key [String] The key to track
  # @return [Boolean] True if tracking was successful, false otherwise
  # @raise [ArgumentError] If the tracker_type is not supported
  def self.track_key(tracker_type, key)
    return false unless key
    
    supported_trackers = [:view_tracker, :translations_tracker, :routes_tracker]
    
    unless supported_trackers.include?(tracker_type)
      raise ArgumentError, "Unsupported tracker type: #{tracker_type}. Must be one of: #{supported_trackers.join(', ')}"
    end
    
    begin
      tracker = configuration.send(tracker_type)
      return false unless tracker && tracker.respond_to?(:track_key)

      tracker.track_key(key)
      true
    rescue => e
      configuration.logger.error "Coverband: Failed to track key '#{key}' with tracker '#{tracker_type}'. Error: #{e.message}"
      false
    end
  end

  private_class_method def self.coverage_instance
    Coverband::Collectors::Coverage.instance
  end

  unless ENV["COVERBAND_DISABLE_AUTO_START"]
    begin
      # Coverband should be setup as early as possible
      # to capture usage of things loaded by initializers or other Rails engines
      # but after gems are loaded to avoid slowing down gem usage
      # best is in application.rb after the bundler line but we get close with Railtie
      if defined? ::Rails::Railtie
        require "coverband/utils/railtie"
      else
        configure
        start
      end
      require "coverband/integrations/resque" if defined? ::Resque
      require "coverband/integrations/sidekiq_swarm" if defined? ::Sidekiq::Enterprise::Swarm
    rescue Redis::CannotConnectError => error
      Coverband.configuration.logger.info "Redis is not available (#{error}), Coverband not configured"
      Coverband.configuration.logger.info "If this is a setup task like assets:precompile feel free to ignore"
    end
  end

  module Reporters
    class Web
      ###
      # NOTE: if the user doesn't setup the webreporter
      # we don't need any of the below files loaded or using memory
      ###
      def initialize
        require "coverband/reporters/web"
        require "coverband/utils/html_formatter"
        require "coverband/utils/result"
        require "coverband/utils/file_list"
        require "coverband/utils/source_file"
        require "coverband/utils/lines_classifier"
        require "coverband/utils/results"
        require "coverband/reporters/html_report"
        require "coverband/reporters/json_report"
        init_web
      end

      def self.call(env)
        @app ||= new
        @app.call(env)
      end
    end
  end
end
