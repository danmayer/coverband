# frozen_string_literal: true

module Coverband
  class AtExit
    @semaphore = Mutex.new

    @at_exit_registered = nil
    def self.register
      return if @at_exit_registered
      @semaphore.synchronize do
        return if @at_exit_registered
        @at_exit_registered = true
        at_exit do
          ::Coverband::Background.stop
          Coverband.report_coverage(true)
          Coverband.configuration.logger&.debug('Coverband: Reported coverage before exit')
        end
      end
    end
  end
end
