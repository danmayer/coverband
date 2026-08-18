# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in coverband.gemspec
gemspec
gem "rails" # latest
gem "haml"
gem "slim"
gem "webrick"

# Required for Ruby 3.4+ (extracted from stdlib)
gem "cgi"

# ActiveSupport 8.1's MemCacheStore passes positional options to ConnectionPool,
# which connection_pool 3.x turned into keyword arguments. Pinned so the
# memcached backed cache adapter tests can actually run.
gem "connection_pool", "~> 2.5"
