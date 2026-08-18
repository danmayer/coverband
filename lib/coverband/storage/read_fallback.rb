# frozen_string_literal: true

module Coverband
  module Storage
    ###
    # Reads degrade instead of raising. A backend that is down, or a Solid Cache
    # table that has not been created yet, must not raise into the request
    # rendering the report.
    #
    # Reads only: write failures keep propagating to the reporting paths that
    # already rescue and log them, so their messages do not disappear.
    #
    # Includers provide @logger and @key_base.
    ###
    module ReadFallback
      private

      def safely(fallback = nil)
        yield
      rescue => error
        log("storage unavailable for #{@key_base}, #{error.class}: #{error.message}")
        fallback
      end

      def log(message)
        @logger&.info("Coverband: #{message}")
      end
    end
  end
end
