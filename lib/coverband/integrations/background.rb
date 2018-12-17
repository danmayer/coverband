# frozen_string_literal: true

module Coverband
  class Background
    @semaphore = Mutex.new

    def self.stop
      @semaphore.synchronize do
        if @thread
          @thread.exit
          @background_reporting_running = false
        end
      end
    end

    def self.start
      return if @background_reporting_running

      logger = Coverband.configuration.logger
      @semaphore.synchronize do
        return if @background_reporting_running
        logger&.debug('Coverband: Starting background reporting')

        @background_reporting_running = true
        sleep_seconds = Coverband.configuration.background_reporting_sleep_seconds
        @thread = Thread.new do
          loop do
            Coverband::Collectors::Coverage.instance.report_coverage(true)
            logger&.debug("Coverband: Reported coverage via thread. Sleeping #{sleep_seconds}s") if Coverband.configuration.verbose
            sleep(sleep_seconds)
          end
        end

        at_exit do
          Coverband::Collectors::Coverage.instance.report_coverage(true)
          logger&.debug('Coverband: Reported coverage before exit')
        end
      end
    end
  end
end
