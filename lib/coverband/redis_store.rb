module Coverband
  class RedisStore
    def initialize(redis)
      @redis = redis
    end

    def store_report(report)
      store_array('coverband', report.keys)

      report.each do |file, lines|
        store_array("coverband.#{file}", lines)
      end
    end

    def sadd_supports_array?
      # if the value is false, ||= would reevaluate the right side
      return @_sadd_supports_array if defined?(@_sadd_supports_array)

      @_sadd_supports_array = recent_gem_version? && recent_server_version?
    end

    private

    attr_reader :redis

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
