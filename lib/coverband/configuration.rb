module Coverband
  class Configuration
    attr_accessor :redis, :coverage_baseline, :root_paths, :root, :ignore, :percentage, :verbose, :reporter, :stats, :logger, :startup_delay
    
    def initialize
      @root = Dir.pwd
      @redis = nil
      @stats = nil
      @coverage_baseline = {}
      @root_paths = []
      @ignore = []
      @percentage = 0.0
      @verbose = false
      @reporter = 'scov'
      @logger = nil
      @startup_delay = 0
    end
  end
end
