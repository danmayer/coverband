# frozen_string_literal: true

module Coverband
  class Background
    @semaphore = Mutex.new
    @thread = nil

    def self.stop
      return unless @thread

      @semaphore.synchronize do
        if @thread
          @thread.exit
          @thread = nil
        end
      end
    end

    def self.running?
      @thread&.alive?
    end

    def self.start
      return if running?

      logger = Coverband.configuration.logger
      @semaphore.synchronize do
        return if running?

        logger.debug('Coverband: Starting background reporting') if Coverband.configuration.verbose
        sleep_seconds = Coverband.configuration.background_reporting_sleep_seconds
        @thread = Thread.new do
          loop do
            Coverband.report_coverage
            Coverband.configuration.view_tracker&.report_views_tracked
            if Coverband.configuration.verbose
              logger.debug("Coverband: background reporting coverage (#{Coverband.configuration.store.type}). Sleeping #{sleep_seconds}s")
            end
            sleep(sleep_seconds)
          end
        end
      end
    end
  end
end
