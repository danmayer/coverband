# frozen_string_literal: true

module Coverband
  module Utils
    module Tasks
      ###
      # Boots the app before touching the store. A lazily configured store
      # (config.store = ActiveSupportCacheStore.new { Rails.cache }) has nothing
      # to resolve until Rails has loaded, so without this every task that
      # reaches storage fails on an unavailable cache.
      ###
      def self.load_environment!
        return unless defined?(Rake) && Rake::Task.task_defined?("environment")

        Rake.application["environment"].invoke
      end

      def self.redis_for_cleanup
        store = Coverband.configuration.store
        if store.respond_to?(:raw_store) && store.raw_store.respond_to?(:scan_each)
          return store.raw_store
        end

        puts "Only a Redis backed store can enumerate its own keys."
        puts "On a cache backed store, clear the cache itself (for example Rails.cache.clear)."
        nil
      rescue NotImplementedError
        puts "This store does not expose a Redis client, nothing to enumerate."
        nil
      end

      ###
      # A generation key is only garbage while its pointer names something else,
      # and deciding that from an earlier snapshot is unsafe: a reset in between
      # would make the new authoritative generation look like an orphan and take
      # the live document with it. Each candidate is re-checked against its
      # pointer immediately before deletion, and anything younger than the grace
      # period is left alone.
      ###
      GRACE_SECONDS = 3600

      def self.remove_orphans(redis, format)
        removed = 0

        redis.scan_each(match: "#{format}*.g*").to_a.uniq.each do |key|
          base = key[/\A(.*)\.g[^.]*\z/, 1]
          token = key[/\.g([^.]*)\z/, 1]
          next unless base && token

          pointer = read_pointer(redis, "#{base}.pointer")
          next if pointer && pointer["token"] == token
          # it may be a generation another process is about to point at
          next if recently_written?(redis, key)

          removed += redis.del(key)
        end

        removed
      end

      def self.read_pointer(redis, key)
        raw = redis.get(key)
        raw ? JSON.parse(raw) : nil
      rescue JSON::ParserError
        nil
      end

      def self.recently_written?(redis, key)
        idle = redis.object("idletime", key)
        idle ? idle < GRACE_SECONDS : true
      rescue
        # if we cannot tell how old it is, leave it alone
        true
      end

      ###
      # Formats no adapter writes any more. What a live adapter still uses is
      # subtracted rather than trusted to a hand-written list: getting this wrong
      # deletes production coverage, and the adapters already know what they own.
      ###
      def self.legacy_formats
        current = [
          Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION,
          Coverband::Adapters::HashRedisStore::REDIS_STORAGE_FORMAT_VERSION,
          Coverband::Adapters::ActiveSupportCacheStore::STORAGE_FORMAT_VERSION
        ]

        %w[coverband_3_2 coverband_hash_3_2 coverband_hash_4_0] - current
      end

      def self.delete_matching(redis, patterns)
        keys = patterns.flat_map { |pattern| redis.scan_each(match: pattern).to_a }.uniq
        keys.any? ? redis.del(*keys) : 0
      end
    end
  end
end

namespace :coverband do
  # handles configuring in require => false and COVERBAND_DISABLE_AUTO_START cases
  Coverband.configure unless Coverband.configured?

  desc "install coverband configuration file defaults"
  task :install do
    require "fileutils"
    full_path = Gem::Specification.find_by_name("coverband").full_gem_path
    config_template = File.expand_path("lib/coverband/utils/configuration_template.rb", full_path)
    FileUtils.cp(config_template, "./config/coverband.rb")
  end

  desc "console formatted report of Coverband code coverage"
  task :coverage do
    Coverband::Utils::Tasks.load_environment!
    require "coverband/utils/html_formatter"
    require "coverband/utils/result"
    require "coverband/utils/file_list"
    require "coverband/utils/source_file"
    require "coverband/utils/lines_classifier"
    require "coverband/utils/results"
    Coverband::Reporters::ConsoleReport.report(Coverband.configuration.store)
  end

  desc "JSON formatted report of Coverband code coverage"
  task :coverage_json do
    Coverband::Utils::Tasks.load_environment!
    require "coverband/utils/html_formatter"
    require "coverband/utils/result"
    require "coverband/utils/file_list"
    require "coverband/utils/source_file"
    require "coverband/utils/lines_classifier"
    require "coverband/utils/results"
    require "coverband/reporters/json_report"

    report = Coverband::Reporters::JSONReport.new(Coverband.configuration.store, {
      for_merged_report: !!ENV["FOR_MERGED_REPORT"],
      line_coverage: true
    }).report
    `mkdir -p coverage`
    File.write("coverage/coverage.json.#{Time.now.to_f}", report)
  end

  ###
  # The Coverband UI now requires the dynamic rack server, however
  # Coverband can still generate a SimpleCov compatible JSON report
  # for use with the SimpleCov HTML formatter.
  #
  # To use this your project Gemfile must include simplecov and simplecov-html
  # gem "simplecov", require: false
  # gem "simplecov-html", require: false
  # the file is written to coverage/index.html
  ###
  desc "static HTML formatted report of Coverband code coverage"
  task :coverage_html do
    Coverband::Utils::Tasks.load_environment!
    require "coverband/utils/html_formatter"
    require "coverband/utils/result"
    require "coverband/utils/file_list"
    require "coverband/utils/source_file"
    require "coverband/utils/lines_classifier"
    require "coverband/utils/results"

    require "simplecov"
    require "simplecov-html"
    `mkdir -p coverage`
    # For a fully static HTML that can be copied to artifacts are part of CI
    # we generate with inline assets
    ENV["SIMPLECOV_INLINE_ASSETS"] = "true"
    coverband_reports = Coverband::Reporters::Base.report(Coverband.configuration.store)
    Coverband::Reporters::Base.fix_reports(coverband_reports)
    result = Coverband::Utils::Results.new(coverband_reports)
    SimpleCov::Formatter::HTMLFormatter.new.format(result)
  end

  ####
  # This task can aggregate multiple coverage files into a single coverage report
  # * `FOR_MERGED_REPORT=true bundle exec rake coverband:coverage_json` to generate the JSON files
  # * collect all the files over time in some system or as artifacts in CI, then run...
  # * `bundle exec rake coverband:aggregate_coverage` to merge the files
  # * the output will include a timestamp of when it was output...
  ####
  task :aggregate_coverage do |task, args|
    require "coverband/utils/result"
    require "coverband/utils/file_list"
    require "coverband/utils/source_file"
    require "coverband/utils/lines_classifier"
    require "coverband/utils/results"
    require "coverband/reporters/json_report"

    directory = "./coverage"
    pattern = "coverage.json*"

    # Use Dir.glob to find files matching the pattern in the specified directory
    files = Dir.glob(File.join(directory, pattern))

    report = {}
    files.each do |file|
      data = JSON.parse(File.read(file))
      report = if report.empty?
        data
      else
        Coverband::Reporters::JSONReport.new(Coverband.configuration.store).merge_reports(report, data)
      end
    end
    File.write("coverage/coverage_merged.json.#{Time.now.to_f}", report.to_json)
  end

  desc "Run a simple rack app to report Coverband code coverage"
  task :coverage_server do
    Coverband::Utils::Tasks.load_environment!
    if Coverband.configuration.store.is_a?(Coverband::Adapters::FileStore)
      Coverband.configuration.store.merge_mode = true
    end

    begin
      require "rackup/server"
      server_class = Rackup::Server
    rescue LoadError
      require "rack/server"
      server_class = Rack::Server
    end

    server_class.start app: Coverband::Reporters::Web.new,
      Port: ENV.fetch("COVERBAND_COVERAGE_PORT", 9022).to_i
  end

  desc "Start MCP server for AI assistant integration (set COVERBAND_MCP_HTTP=true for HTTP mode)"
  task :mcp do
    # In stdio mode, we must suppress all non-JSON-RPC output to stdout to comply with
    # the MCP stdio transport spec. Otherwise, Rails logger and gem output will pollute
    # the JSON-RPC stream and break clients like Claude Desktop.
    # See https://github.com/danmayer/coverband/issues/625
    use_stdio_mode = !ENV["COVERBAND_MCP_HTTP"]

    original_stdout = nil
    if use_stdio_mode
      # Save original stdout and redirect stdout to stderr temporarily
      original_stdout = $stdout
      $stdout = $stderr
    end

    Coverband::Utils::Tasks.load_environment!

    if use_stdio_mode
      # Restore stdout for JSON-RPC communication over stdio
      $stdout = original_stdout
    end

    begin
      require "coverband/mcp"
    rescue LoadError
      abort "The 'mcp' gem is required for MCP server support. Add `gem 'mcp'` to your Gemfile."
    end

    server = Coverband::MCP::Server.new

    if ENV["COVERBAND_MCP_HTTP"]
      # HTTP mode with Streamable HTTP transport (SSE)
      begin
        require "rackup"
      rescue LoadError
        abort "The 'rackup' gem is required for HTTP mode. Add `gem 'rackup'` to your Gemfile."
      end

      port = ENV.fetch("COVERBAND_MCP_PORT", 9023).to_i
      host = ENV.fetch("COVERBAND_MCP_HOST", "localhost")
      server.run_http(port: port, host: host)
    else
      # Default stdio mode
      server.run_stdio
    end
  end

  # experimental dead method detection using RubyVM::AbstractSyntaxTree
  # combined with the coverband coverage.
  if defined?(RubyVM::AbstractSyntaxTree)
    require "coverband/utils/dead_methods"

    desc "Output all dead methods"
    task :dead_methods do
      Coverband::Utils::DeadMethods.output_all
    end
  end

  ###
  # clear all coverband data
  ###
  desc "reset Coverband coverage and trackers data, helpful for development, debugging, etc"
  task clear: [:clear_coverage, :clear_tracker]

  ###
  # clear coverband coverage data
  ###
  desc "reset Coverband coverage data, helpful for development, debugging, etc"
  task :clear_coverage do
    Coverband::Utils::Tasks.load_environment!
    Coverband.configuration.store.clear!
  end

  ###
  # 7.0 changed the storage format, so pre-upgrade keys are ignored rather than
  # migrated; this deletes them once the new data looks right. Scoped to
  # Coverband's own namespaces and tracker names, since a bare "*_tracker" glob
  # would happily delete an application's keys out of the same database.
  ###
  desc "delete Coverband data left behind by pre 7.0 storage formats (Redis only)"
  task :clear_legacy do
    Coverband::Utils::Tasks.load_environment!
    redis = Coverband::Utils::Tasks.redis_for_cleanup
    next unless redis

    namespaces = [Coverband.configuration.redis_namespace, nil].uniq
    trackers = %w[ViewTracker RouteTracker TranslationTracker QueryBurstTracker]

    legacy_formats = Coverband::Utils::Tasks.legacy_formats

    patterns = legacy_formats.map { |format| "#{format}*" }
    namespaces.each do |namespace|
      trackers.each do |tracker|
        prefix = namespace ? "#{namespace}_#{tracker}" : tracker
        patterns << "#{prefix}_tracker"
        patterns << "#{prefix}_tracker_time"
      end
    end

    puts "removed #{Coverband::Utils::Tasks.delete_matching(redis, patterns)} legacy Coverband keys"
  end

  ###
  # A reset deletes the key it retires, but a straggler mid-write can recreate it
  # afterwards, and two racing resets can lose one another's cleanup instruction,
  # so orphans accumulate with nothing to reclaim them.
  #
  # Redis only, since only Redis can enumerate its own keys. On a cache backed
  # store the backend's expiry, or clearing the cache, is the equivalent.
  ###
  desc "delete Coverband generation keys no longer referenced by any pointer (Redis only)"
  task :clear_orphans do
    Coverband::Utils::Tasks.load_environment!
    redis = Coverband::Utils::Tasks.redis_for_cleanup
    next unless redis

    formats = [
      Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION,
      Coverband::Adapters::HashRedisStore::REDIS_STORAGE_FORMAT_VERSION
    ].uniq

    removed = formats.sum { |format| Coverband::Utils::Tasks.remove_orphans(redis, format) }
    puts "removed #{removed} orphaned Coverband generation keys"
  end

  ###
  # clear all coverband trackers data
  ###
  desc "reset Coverband trackers data (view, routes, translations, etc), helpful for development, debugging, etc"
  task :clear_tracker do
    Coverband::Utils::Tasks.load_environment!
    # Load rails-related trackers, if the gem is used in a rails app.
    Coverband.configuration.railtie! if defined?(Rails::Railtie)

    trackers = Coverband.configuration.trackers
    trackers.each(&:reset_recordings)
  end
end
