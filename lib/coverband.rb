require 'redis'

require "coverband/version"
require "coverband/reporter"
require "coverband/middleware"

module Coverband

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  class Configuration
    attr_accessor :redis, :coverage_baseline, :root_paths, :root, :ignore, :percentage, :verbose, :reporter
    
    def initialize
      @root = Dir.pwd
      @redis = nil
      @coverage_baseline = {}
      @root_paths = []
      @ignore = []
      @percentage = 100.0
      @verbose = false
      @reporter = 'rcov'
    end
  end
  
end
