# frozen_string_literal: true

require 'logger'
require 'json'

require 'coverband/version'
require 'coverband/configuration'
require 'coverband/adapters/base'
require 'coverband/adapters/redis_store'
require 'coverband/adapters/memory_cache_store'
require 'coverband/adapters/file_store'
require 'coverband/adapters/s3_report_writer'
require 'coverband/collectors/base'
require 'coverband/collectors/coverage'
require 'coverband/reporters/base'
require 'coverband/reporters/simple_cov_report'
require 'coverband/reporters/console_report'
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
      raise ArgumentError, "configure requires a block, #{CONFIG_FILE} in project, or file path passed in configure"
    end
  end

  def self.configuration
    self.configuration_data ||= Configuration.new
  end
end
