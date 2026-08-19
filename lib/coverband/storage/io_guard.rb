# frozen_string_literal: true

module Coverband
  module Storage
    ###
    # Marks the current thread as being inside Coverband's own storage I/O.
    #
    # A database backed cache (Solid Cache) turns every read, write, and delete
    # into SQL, which QueryBurstTracker would otherwise attribute to whatever
    # action or job triggered the report. Released in an ensure, so a raise
    # inside storage I/O can't leave the guard set and silence real queries.
    ###
    module IOGuard
      KEY = :coverband_storage_io

      def self.active?
        (Thread.current[KEY] || 0) > 0
      end

      def self.guard
        Thread.current[KEY] = (Thread.current[KEY] || 0) + 1
        yield
      ensure
        depth = (Thread.current[KEY] || 1) - 1
        Thread.current[KEY] = (depth > 0) ? depth : nil
      end
    end
  end
end
