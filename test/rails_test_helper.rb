# Configure Rails Environment
ENV["RAILS_ENV"] = "test"
require 'rails'
require File.expand_path('./test_helper', File.dirname(__FILE__))
require_relative "../test/rails#{Rails::VERSION::MAJOR}_dummy/config/environment"
require 'capybara/rails'
require 'capybara/minitest'

#Our coverage report is wrapped in display:none as of now
Capybara.ignore_hidden_elements = false
