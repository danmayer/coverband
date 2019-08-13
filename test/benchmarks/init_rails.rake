# frozen_string_literal: true

require 'rails'
require 'coverband'

desc 'Initialize rails'
task 'init_rails' do
  Coverband.configure("./test/rails#{Rails::VERSION::MAJOR}_dummy/config/coverband.rb")
  require "./test/rails#{Rails::VERSION::MAJOR}_dummy/config/environment"
end
