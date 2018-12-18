# Configure Rails Environment
ENV["RAILS_ENV"] = "test"
require 'rails'
ENV['COVERBAND_CONFIG'] = "./test/rails#{Rails::VERSION::MAJOR}_dummy/config/coverband.rb"
require File.expand_path('./test_helper', File.dirname(__FILE__))
require_relative "../test/rails#{Rails::VERSION::MAJOR}_dummy/config/environment"
