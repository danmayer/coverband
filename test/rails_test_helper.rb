# frozen_string_literal: true

require 'minitest'
require 'minitest/fork_executor'

# Forked executor includes autorun which does not work with qrush/m
# https://github.com/qrush/m/issues/26
# https://github.com/seattlerb/minitest/blob/master/lib/minitest/autorun.rb
if defined?(M)
  Minitest.class_eval do
    def self.autorun
      puts 'No autorunning'
    end
  end
end

Minitest.parallel_executor = Minitest::ForkExecutor.new
require File.expand_path('./test_helper', File.dirname(__FILE__))
require 'capybara'
require 'capybara/minitest'
def rails_setup
  ENV['RAILS_ENV'] = 'test'
  require 'rails'
  # coverband must be required after rails
  load 'coverband/utils/railtie.rb'
  Coverband.configure("./test/rails#{Rails::VERSION::MAJOR}_dummy/config/coverband.rb")
  require_relative "../test/rails#{Rails::VERSION::MAJOR}_dummy/config/environment"
  require 'capybara/rails'
  # Our coverage report is wrapped in display:none as of now
  Capybara.ignore_hidden_elements = false
  require 'mocha/minitest'
end
