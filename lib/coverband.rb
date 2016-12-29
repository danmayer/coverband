require 'redis'
require 'logger'
# todo this shouldn't be required, but allowed if they use S3 output
require 'aws-sdk'

require 'coverband/version'
require 'coverband/configuration'
require 'coverband/adapters/redis_store'
require 'coverband/adapters/memory_cache_store'
require 'coverband/base'
require 'coverband/baseline'
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

  # this method is left for backwards compatibility with existing configs
  def self.parse_baseline(baseline_file = './tmp/coverband_baseline.json')
    Coverband::Baseline.parse_baseline(baseline_file)
  end

  def self.configure(file = nil)
    configuration
    if block_given?
      yield(configuration)
    else
      if File.exists?(CONFIG_FILE)
        file ||= CONFIG_FILE
        require file
      else
        raise ArgumentError, "configure requires a block or the existance of a #{CONFIG_FILE} in your project"
      end
    end
  end

  def self.configuration
    self.configuration_data ||= Configuration.new
  end

end
