# frozen_string_literal: true

require 'logger'
require 'json'

require 'coverband/version'
require 'coverband/configuration'
require 'coverband/adapters/base'
require 'coverband/adapters/redis_store'
require 'coverband/adapters/file_store'
require 'coverband/utils/s3_report'
require 'coverband/utils/railtie' if defined? ::Rails::Railtie
require 'coverband/collectors/coverage'
require 'coverband/reporters/base'
require 'coverband/reporters/simple_cov_report'
require 'coverband/reporters/console_report'
require 'coverband/integrations/background'
require 'coverband/integrations/rack_server_check'
require 'coverband/reporters/web'
require 'coverband/integrations/middleware'
require 'coverband/integrations/background'

module Coverband
  CONFIG_FILE = './config/coverband.rb'

  class << self
    attr_accessor :configuration_data
  end

  def self.configure(file = nil)
    configuration_file = file || CONFIG_FILE

    configuration
    if block_given?
      yield(configuration)
    elsif File.exist?(configuration_file)
      require configuration_file
    else
      configuration.logger&.debug('using default configuration')
    end
  end

  def self.configuration
    self.configuration_data ||= Configuration.new
  end

  def self.start
    Coverband::Collectors::Coverage.instance
    Background.start if configuration.background_reporting_enabled && !RackServerCheck.running?
  end
end
