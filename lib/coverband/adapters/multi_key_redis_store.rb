# frozen_string_literal: true

module Coverband
  module Adapters
    class MultiKeyRedisStore < Base
      def initialize(redis, _opts = {})
        super()
        @redis = redis
      end

      def clear!; end

      def save_report(report)
        expand_report(report).each do |file, data|
          @redis.set(file, data.to_json)
        end
      end

      def coverage
        @redis.keys('*').each_with_object({}) do |key, coverage|
          coverage[key] = JSON.parse(@redis.get(key))
        end
      end
    end
  end
end
