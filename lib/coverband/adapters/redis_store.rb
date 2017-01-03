module Coverband
  module Adapters
    class RedisStore
      def initialize(redis, opts = {})
        @redis = redis
        @_sadd_supports_array = recent_gem_version? && recent_server_version?
        @store_as_array = opts.fetch(:array){ false }
      end

      def clear!
        @redis.smembers('coverband').each { |key| @redis.del("coverband.#{key}") }
        @redis.del("coverband")
      end

      def save_report(report)
        if @store_as_array
          redis.pipelined do
            store_array('coverband', report.keys)

            report.each do |file, lines|
              store_array("coverband.#{file}", lines.keys)
            end
          end
        else
          store_array('coverband', report.keys)

          report.each do |file, lines|
            store_map("coverband.#{file}", lines)
          end
        end
      end

      def coverage
        data = {}
        redis.smembers('coverband').each do |key|
          data[key] = covered_lines_for_file(key)
        end
        data
      end

      def covered_files
        redis.smembers('coverband')
      end

      def covered_lines_for_file(file)
        if @store_as_array
          @redis.smembers("coverband.#{file}").map(&:to_i)
        else
          @redis.hgetall("coverband.#{file}")
        end
      end

      private

      attr_reader :redis

      def sadd_supports_array?
        @_sadd_supports_array
      end

      def store_map(key, values)
        unless values.empty?
          existing = redis.hgetall(key)
          #in redis all keys are strings
          values = Hash[values.map{|k,val| [k.to_s,val] } ]
          values.merge!( existing ){|k, old_v, new_v| old_v.to_i + new_v.to_i}
          redis.mapped_hmset(key, values)
        end
      end

      def store_array(key, values)
        if sadd_supports_array?
          redis.sadd(key, values) if (values.length > 0)
        else
          values.each do |value|
            redis.sadd(key, value)
          end
        end
        values
      end

      def recent_server_version?
        info_data = redis.info
        if info_data.is_a?(Hash)
          Gem::Version.new(info_data['redis_version']) >= Gem::Version.new('2.4')
        else
          #guess supported
          true
        end
      end

      def recent_gem_version?
        Gem::Version.new(Redis::VERSION) >= Gem::Version.new('3.0')
      end
    end
  end
end
