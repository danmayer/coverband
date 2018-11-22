# frozen_string_literal: true

module Coverband
  class Background
    @semaphore = Mutex.new

    def self.start
      return if @background_reporting_running

      logger = Coverband.configuration.logger
      @semaphore.synchronize do
        return if @background_reporting_running
        logger&.debug('Starting background reporting')

        @background_reporting_running = true
        sleep_seconds = Coverband.configuration.background_reporting_sleep_seconds
        Thread.new do
          loop do
            Coverband::Collectors::Coverage.instance.report_coverage(true)
            logger&.debug("Reported coverage from thread. Sleeping for #{sleep_seconds} seconds")
            sleep(sleep_seconds)
          end
        end

        at_exit do
          Coverband::Collectors::Coverage.instance.report_coverage(true)
          logger&.debug('Reported coverage before exit')
        end
      end
    end
  end
end
