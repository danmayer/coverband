# frozen_string_literal: true

require 'logger'
require 'json'

require 'coverband/version'
require 'coverband/configuration'
require 'coverband/adapters/base'
require 'coverband/adapters/redis_store'
require 'coverband/adapters/memory_cache_store'
require 'coverband/adapters/file_store'
require 'coverband/collectors/base'
require 'coverband/collectors/trace'
require 'coverband/collectors/coverage'
require 'coverband/reporters/base'
require 'coverband/reporters/simple_cov_report'
require 'coverband/reporters/console_report'
require 'coverband/middleware'
require 'coverband/s3_report_writer'

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
      raise ArgumentError, "configure requires a block, the existance of a #{CONFIG_FILE} in your project, or a path to a config file passed in to configure"
    end
  end

  def self.configuration
    self.configuration_data ||= Configuration.new
  end
end
