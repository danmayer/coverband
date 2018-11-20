# Configure Rails Environment
ENV["RAILS_ENV"] = "test"
require 'rails'
require File.expand_path('./test_helper', File.dirname(__FILE__))

if Rails::VERSION::MAJOR >= 5
  require_relative "../test/rails5_dummy/config/environment"
else
  require_relative "../test/rails4_dummy/config/environment"
end

