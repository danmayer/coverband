# frozen_string_literal: true

module Coverband
  class Background
    @semaphore = Mutex.new

    def self.start
      return if @background_reporting_running

      @semaphore.synchronize do
        return if @background_reporting_running

        @background_reporting_running = true
        sleep_seconds = Coverband.configuration.background_reporting_sleep_seconds
        logger = Coverband.configuration.logger
        Thread.new do
          loop do
            Coverband::Collectors::Coverage.instance.report_coverage
            logger&.debug("Reported coverage from thread. Sleeping for #{sleep_seconds} seconds")
            sleep(sleep_seconds)
          end
        end
      end
    end
  end
end
