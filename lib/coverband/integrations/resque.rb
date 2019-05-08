# frozen_string_literal: true

Resque.after_fork do |_job|
  Coverband.start
  Coverband.runtime_coverage!
end

Resque.before_first_fork do
  Coverband.eager_loading_coverage!
  Coverband.configuration.background_reporting_enabled = false
  Coverband::Background.stop
  Coverband::Collectors::Coverage.instance.report_coverage
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

Resque::Job.prepend(Coverband::ResqueWorker)
