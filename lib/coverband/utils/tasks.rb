# frozen_string_literal: true

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

  desc "console formated report of Coverband code coverage"
  task :coverage do
    require "coverband/utils/html_formatter"
    require "coverband/utils/result"
    require "coverband/utils/file_list"
    require "coverband/utils/source_file"
    require "coverband/utils/lines_classifier"
    require "coverband/utils/results"
    Coverband::Reporters::ConsoleReport.report(Coverband.configuration.store)
  end

  desc "JSON formated report of Coverband code coverage"
  task :coverage_json do
    require "coverband/utils/html_formatter"
    require "coverband/utils/result"
    require "coverband/utils/file_list"
    require "coverband/utils/source_file"
    require "coverband/utils/lines_classifier"
    require "coverband/utils/results"
    require "coverband/reporters/json_report"

    report = Coverband::Reporters::JSONReport.new(Coverband.configuration.store).report
    File.write("coverage/coverage.json", report)
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
  desc "static HTML formated report of Coverband code coverage"
  task :coverage_html do
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

  desc "Run a simple rack app to report Coverband code coverage"
  task :coverage_server do
    if Rake::Task.task_defined?("environment")
      Rake.application["environment"].invoke
    end
    if Coverband.configuration.store.is_a?(Coverband::Adapters::FileStore)
      Coverband.configuration.store.merge_mode = true
    end
    Rack::Server.start app: Coverband::Reporters::Web.new,
      Port: ENV.fetch("COVERBAND_COVERAGE_PORT", 9022).to_i
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
  # clear data helpful for development or after configuration issues
  ###
  desc "reset Coverband coverage data, helpful for development, debugging, etc"
  task :clear do
    Coverband.configuration.store.clear!
  end

  ###
  # clear all coverband trackers data
  ###
  desc "reset Coverband trackers data (view, routes, translations, etc), helpful for development, debugging, etc"
  task :clear_tracker do
    trackers = Coverband.configuration.trackers
    trackers.each(&:reset_recordings)
  end
end
