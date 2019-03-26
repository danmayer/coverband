require File.expand_path('./test_helper', File.dirname(__FILE__))
require 'capybara'
require 'capybara/minitest'
def rails_setup
  ENV["RAILS_ENV"] = "test"
  require 'rails'
  #coverband must be required after rails
  load 'coverband/utils/railtie.rb'
  Coverband.configure("./test/rails#{Rails::VERSION::MAJOR}_dummy/config/coverband.rb")
  require_relative "../test/rails#{Rails::VERSION::MAJOR}_dummy/config/environment"
  require 'capybara/rails'
  #Our coverage report is wrapped in display:none as of now
  Capybara.ignore_hidden_elements = false
  require 'mocha/minitest'
end

