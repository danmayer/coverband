# frozen_string_literal: true

require "logger"
require "json"
require "redis"
require "coverband/version"
require "coverband/at_exit"
require "coverband/configuration"
require "coverband/utils/relative_file_converter"
require "coverband/utils/absolute_file_converter"
require "coverband/adapters/base"
require "coverband/adapters/redis_store"
require "coverband/adapters/hash_redis_store"
require "coverband/adapters/file_store"
require "coverband/adapters/stdout_store"
require "coverband/utils/file_hasher"
require "coverband/collectors/coverage"
require "coverband/collectors/view_tracker"
require "coverband/reporters/base"
require "coverband/reporters/console_report"
require "coverband/integrations/background"
require "coverband/integrations/background_middleware"
require "coverband/integrations/rack_server_check"

Coverband::Adapters::RedisStore = Coverband::Adapters::HashRedisStore if ENV["COVERBAND_HASH_REDIS_STORE"]

module Coverband
  @@configured = false
  CONFIG_FILE = "./config/coverband.rb"
  RUNTIME_TYPE = :runtime
  EAGER_TYPE = :eager_loading
  MERGED_TYPE = :merged
  TYPES = [RUNTIME_TYPE, EAGER_TYPE]
  ALL_TYPES = TYPES + [:merged]

  def self.configure(file = nil)
    configuration_file = file || ENV.fetch("COVERBAND_CONFIG", CONFIG_FILE)
    configuration
    if block_given?
      yield(configuration)
    elsif File.exist?(configuration_file)
      load configuration_file
    else
      configuration.logger.debug("using default configuration")
    end
    @@configured = true
    coverage_instance.reset_instance
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
    (defined?(Rake) &&
    Rake.respond_to?(:application) &&
    (Rake&.application&.top_level_tasks || []).any? { |task| Coverband::Configuration::IGNORE_TASKS.include?(task) })
  end

  def self.eager_loading_coverage!
    coverage_instance.eager_loading!
  end

  def self.eager_loading_coverage(&block)
    coverage_instance.eager_loading(&block)
  end

  def self.runtime_coverage!
    coverage_instance.runtime!
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
        init_web
      end
    end
  end
end
