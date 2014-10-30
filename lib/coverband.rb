require 'redis'
require 'logger'

require 'coverband/version'
require 'coverband/configuration'
require 'coverband/redis_store'
require 'coverband/base'
require 'coverband/reporter'
require 'coverband/middleware'

module Coverband

  CONFIG_FILE = './config/coverband.rb'
  
  class << self
    attr_accessor :configuration_data
  end

  def self.parse_baseline(baseline_file = './tmp/coverband_baseline.json')
    baseline = if File.exist?(baseline_file)
      JSON.parse(File.read(baseline_file))
    else
      {}
    end
  end

  def self.configure(file = nil)
    self.configuration_data ||= Configuration.new
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
