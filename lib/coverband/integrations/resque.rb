# frozen_string_literal: true

Resque.after_fork do |job|
  Coverband.start
end

module Coverband
  module ResqueWorker
    def perform
      super
    ensure
      Coverband::Collectors::Coverage.instance.report_coverage(true)
    end
  end
end

Resque::Job.prepend(Coverband::ResqueWorker)

