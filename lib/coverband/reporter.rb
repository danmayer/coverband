module Coverband

  class Reporter
    
    def self.report(redis)
      lines_run = redis.smembers('coverband').each{|key| report_line(redis, key) }
    end

    private

    def self.report_line(redis, key)
      puts "#{key.gsub('.','/')}: #{redis.smembers("coverband#{key}").inspect}"
    end

  end

end
