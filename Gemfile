# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in coverband.gemspec
gemspec

# add when debugging
# require 'byebug'; byebug
if ENV["CI"]
  # skipping pry-byebug as it has issues on Ruby 2.3 on travis
  # and we don't really need it on CI
else
  gem "pry-byebug", platforms: [:mri, :mingw, :x64_mingw]
end

gem "rails", "~>5"
gem "haml"
gem "slim"
# these gems are used for testing gem tracking
gem "irb", require: false
