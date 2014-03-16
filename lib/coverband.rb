require 'redis'
require 'logger'

require 'coverband/version'
require 'coverband/configuration'
require 'coverband/redis_store'
require 'coverband/base'
require 'coverband/reporter'
require 'coverband/middleware'

module Coverband

  class << self
    attr_accessor :configuration
  end

  def self.configure(file = nil)
    self.configuration ||= Configuration.new
    if file
      puts "hooray"
      raise "boom"
    else
      yield(configuration)
    end
  end
  
end
