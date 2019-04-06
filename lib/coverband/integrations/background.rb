# frozen_string_literal: true

module Coverband
  class Background
    @semaphore = Mutex.new

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
      @thread && @thread.alive?
    end

    def self.start
      return if running?

      logger = Coverband.configuration.logger
      @semaphore.synchronize do
        return if running?
        logger&.debug('Coverband: Starting background reporting')
        sleep_seconds = Coverband.configuration.background_reporting_sleep_seconds
        @thread = Thread.new do
          loop do
            puts "Background thread reporting pid: #{Process.pid}"
            Coverband.report_coverage(true)
            logger&.debug("Coverband: Reported coverage via thread. Sleeping #{sleep_seconds}s") if Coverband.configuration.verbose
            sleep(sleep_seconds)
          end
        end
      end
    end
  end
end
