module Coverband
  module Adapters
    class RedisStore
      BASE_KEY = 'coverband1'

      def initialize(redis, opts = {})
        @redis = redis
        #remove check for coverband 2.0
        @_sadd_supports_array = recent_gem_version? && recent_server_version?
        #possibly drop array storage for 2.0
        @store_as_array  = opts.fetch(:array){ false }
        @ttl             = opts[:ttl]
        @redis_namespace = opts[:redis_namespace]
      end

      def base_key
        @base_key || [BASE_KEY, @redis_namespace].compact.join('.')
      end

      def clear!
        @redis.smembers(base_key).each { |key| @redis.del("#{base_key}.#{key}") }
        @redis.del(base_key)
      end

      def save_report(report)
        if @store_as_array
          redis.pipelined do
            store_array(base_key, report.keys)

            report.each do |file, lines|
              store_array("#{base_key}.#{file}", lines.keys)
            end
          end
        else
          if sadd_supports_array?
            redis.pipelined do
              redis.sadd(base_key, report.keys) if (report.keys.length > 0)
              redis.expire(base_key, @ttl) if @ttl
              report.each do |file, lines|
                lines.each { |line, count| redis.hincrby("#{base_key}.#{file}", line, count) }
                redis.expire("#{base_key}.#{file}", @ttl) if @ttl
              end              
            end
          else
            store_array(base_key, report.keys)
            report.each do |file, lines|
              store_map("#{base_key}.#{file}", lines)
            end
          end
        end
      end

      def coverage
        data = {}
        redis.smembers(base_key).each do |key|
          data[key] = covered_lines_for_file(key)
        end
        data
      end

      def covered_files
        redis.smembers(base_key)
      end

      def covered_lines_for_file(file)
        if @store_as_array
          @redis.smembers("#{base_key}.#{file}").map(&:to_i)
        else
          @redis.hgetall("#{base_key}.#{file}")
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
          redis.expire(key, @ttl) if @ttl
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
        redis.expire(key, @ttl) if @ttl
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
