# frozen_string_literal: true

module Coverband
  module Adapters
    ###
    # StdoutStore is for testing and development
    #
    # Usage:
    # config.store = Coverband::Adapters::StdoutStore.new
    ###
    class StdoutStore < Base
      def initialize(_opts = {})
        super()
      end

      def clear!
        # NOOP
      end

      def size
        0
      end

      def coverage(_local_type = nil, opts = {})
        {}
      end

      def save_report(report)
        $stdout.puts(report.to_json)
      end

      def raw_store
        raise NotImplementedError, "StdoutStore doesn't support raw_store"
      end
    end
  end
end
