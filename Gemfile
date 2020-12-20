# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in coverband.gemspec
gemspec

# add when debugging
# require 'byebug'; byebug
unless ENV["CI"]
  gem "pry-byebug"
end

gem "rails", "~>5"
gem "haml"
gem "slim"
# these gems are used for testing gem tracking
gem "irb", require: false
