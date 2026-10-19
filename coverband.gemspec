# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "coverband/version"

Gem::Specification.new do |spec|
  spec.name = "coverband"
  spec.version = Coverband::VERSION
  spec.authors = ["Dan Mayer", "Karl Baum"]
  spec.email = %w[dan@mayerdan.com]
  spec.description =
    "Rack middleware to measure production code usage (LOC runtime usage)"
  spec.summary =
    "Rack middleware to measure production code usage (LOC runtime usage)"
  spec.homepage = "https://github.com/danmayer/coverband"
  spec.license = "MIT"

  spec.files = `git ls-files`.split("\n").reject { |f| f.start_with?("docs") }
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = %w[lib]

  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "homepage_uri" => "https://github.com/danmayer/coverband",
    "bug_tracker_uri" => "https://github.com/danmayer/coverband/issues",
    "documentation_uri" => "https://github.com/danmayer/coverband",
    "changelog_uri" => "https://github.com/danmayer/coverband/blob/main/changes.md",
    "source_code_uri" => "https://github.com/danmayer/coverband"
  }

  spec.add_development_dependency "benchmark-ips"
  spec.add_development_dependency "benchmark" # Ruby 4.0+ requires explicit dependency
  spec.add_development_dependency "capybara"
  spec.add_development_dependency "m"
  spec.add_development_dependency "memory_profiler"
  # breaking change in minitest and mocha...
  # note: we are also adding 'spy' as mocha doesn't want us to spy on redis calls...
  spec.add_development_dependency "spy"
  # ^^^ probably need a large test cleanup refactor
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-fork_executor"
  spec.add_development_dependency "minitest-stub-const"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "rack"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "resque"
  spec.add_development_dependency "standard", ">= 1.35.1"
  # json 3 rejects the quirks_mode option ActiveSupport 7.0 - 8.0 still passes when
  # encoding, and breaks multi_json (used by resque) on Ruby 3.1
  spec.add_development_dependency "json", "< 3"
  # minitest-profile is not compatible with Rails 7.1.0 setup... dropping it for now
  # spec.add_development_dependency "minitest-profile"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "dalli" # memcached client for the cache adapter tests
  # the cache adapter duck types the ActiveSupport::Cache::Store interface and
  # never requires it, but the tests need real cache stores to run against
  spec.add_development_dependency "activesupport"
  spec.add_development_dependency "mcp" # For MCP server support testing

  # Redis is optional since 7.0: it stays the default store whenever the redis gem
  # is installed, and the ActiveSupport cache adapter covers everything else.
  spec.add_development_dependency "redis", ">= 3.0"

  spec.post_install_message = <<~MSG
    Coverband 7.0 no longer depends on the redis gem. Redis is still the default
    store, so if you use it add `gem "redis"` to your Gemfile. To store coverage
    elsewhere (Solid Cache, memcached, files) see config.store in the README.
    Coverage stored by Coverband 6.x is not carried over; see changes.md.
  MSG
end
