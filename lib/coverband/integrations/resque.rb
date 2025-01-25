# frozen_string_literal: true

Resque.after_fork do |_job|
  Coverband.start
  Coverband.runtime_coverage!
end

Resque.before_first_fork do
  Coverband.eager_loading_coverage!
  Coverband.configuration.background_reporting_enabled = false
  Coverband::Background.stop
  Coverband.report_coverage

  Coverband.configuration.store = Coverband::Adapters::FileStore.new(Coverband.configuration.filepath_pattern_for_multi_process)
  Coverband::Collectors::Coverage.instance.reset_instance
  Coverband::BackgroundForMultiProcess.start
end

module Coverband
  module ResqueWorker
    def perform
      super
    ensure
      Coverband.report_coverage
    end
  end
end

if defined?(Coverband::COVERBAND_ALTERNATE_PATCH)
  Resque::Job.class_eval do
    def perform_with_coverband
      perform_without_coverband
    ensure
      Coverband.report_coverage
    end
    alias perform_without_coverband perform
    alias perform perform_with_coverband
  end
else
  Resque::Job.prepend(Coverband::ResqueWorker)
end
