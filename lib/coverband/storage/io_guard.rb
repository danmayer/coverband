# frozen_string_literal: true

module Coverband
  module Storage
    ###
    # Marks the current thread as being inside Coverband's own storage I/O.
    #
    # A database backed cache (Solid Cache) turns every read, write, and delete
    # into SQL, which QueryBurstTracker would otherwise attribute to whatever
    # controller action or job happened to trigger the report. Wrapping every
    # call into the cache target lets the tracker skip its own noise.
    #
    # Nesting safe, and released in an ensure so a raise inside storage I/O
    # can't leave the guard set and silence the app's real queries.
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
        Thread.current[KEY] = if depth > 0
          depth
        end
      end
    end
  end
end
