# frozen_string_literal: true

module Coverband
  module Adapters
    ###
    # NullStore is for benchmarking the impacts of calculating
    # and storing coverage data independent of Coverband/Coverage
    #
    # Usage:
    # config.store = Coverband::Adapters::NullStore.new
    ###
    class NullStore < Base
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
        # NOOP
      end

      def raw_store
        raise NotImplementedError, "NullStore doesn't support raw_store"
      end
    end
  end
end
