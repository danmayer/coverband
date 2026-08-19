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

# Solid Cache is a central target for the ActiveSupport::Cache adapter: it is
# how Coverband reaches Postgres, MySQL, and SQLite. Needs Rails 7.2+.
#
# Kept out of the default group on purpose: the dummy Rails apps require every
# default gem, and Solid Cache's engine expects an ActiveJob they do not load.
group :solid_cache, optional: true do
  gem "solid_cache"
  gem "sqlite3"
end
