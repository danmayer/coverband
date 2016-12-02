module Coverband
  class RedisStore
    def initialize(redis)
      @redis = redis
      @_sadd_supports_array = recent_gem_version? && recent_server_version?
    end

    def store_report(report)
      redis.pipelined do
        store_array('coverband', report.keys)

        report.each do |file, lines|
          store_array("coverband.#{file}", lines.keys)
        end
      end
    end


    def covered_lines_for_file(file)
      @redis.smembers("coverband.#{file}").map(&:to_i)
    end


    def sadd_supports_array?
      @_sadd_supports_array
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
