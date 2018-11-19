# Configure Rails Environment
ENV["RAILS_ENV"] = "test"
require 'rails'
require File.expand_path('./test_helper', File.dirname(__FILE__))

require_relative "../test/dummy/config/environment"

