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

        logger.debug("Coverband: Starting background reporting") if Coverband.configuration.verbose
        sleep_seconds = Coverband.configuration.background_reporting_sleep_seconds.to_i
        @thread = Thread.new {
          Thread.current.name = "Coverband Background Reporter"

          loop do
            if Coverband.configuration.reporting_wiggle
              sleep_seconds = Coverband.configuration.background_reporting_sleep_seconds.to_i + rand(Coverband.configuration.reporting_wiggle.to_i)
            end
            # NOTE: Normally as processes first start we immediately report, this causes a redis spike on deploys
            # if deferred is set also sleep frst to spread load
            sleep(sleep_seconds.to_i) if Coverband.configuration.defer_eager_loading_data?
            Coverband.report_coverage
            Coverband.configuration.trackers.each { |tracker| tracker.save_report }
            if Coverband.configuration.verbose
              logger.debug("Coverband: background reporting coverage (#{Coverband.configuration.store.type}). Sleeping #{sleep_seconds}s")
            end
            sleep(sleep_seconds.to_i) unless Coverband.configuration.defer_eager_loading_data?
          end
        }
      end
    rescue ThreadError
      stop
    end
  end
end
