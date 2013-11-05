require 'simplecov'

module Coverband

  class Reporter
    
    def self.report(redis)
      #redis.smembers('coverband').each{|key| report_line(redis, key) }
      report_rcov(redis)
    end

    private

    def self.report_rcov(redis)
      rcov_style_report = {}
      redis.smembers('coverband').each{|key| rcov_style_report.merge!(line_hash(redis, key)) }
      puts rcov_style_report.inspect
      SimpleCov::Result.new(rcov_style_report).format!
      `open coverage/index.html`
    end

    # /Users/danmayer/projects/cover_band_server/views/index/erb: ["0", "2", "3", "6", "65532", "65533"]
    # /Users/danmayer/projects/cover_band_server/app/rb: ["54", "55"]
    # /Users/danmayer/projects/cover_band_server/views/layout/erb: ["0", "33", "36", "37", "38", "39", "40", "62", "63", "66", "65532", "65533"]
    def self.report_line(redis, key)
      puts "#{key.gsub('.','/')}: #{redis.smembers("coverband#{key}").inspect}"
    end

    # >> puts  Coverage.result.inspect
    # {"/Users/danmayer/projects/hearno/script/tester.rb"=>[1, nil, 1, 1, nil, nil, nil]}
    def self.line_hash(redis, key)
      filename = key.gsub('.','/').gsub('/rb','.rb').gsub('/erb','.erb')

      lines_hit = redis.smembers("coverband#{key}")
      count = File.foreach(filename).inject(0) {|c, line| c+1}
      line_array = Array.new(count, 0)
      puts lines_hit
      line_array.each_with_index{|line,index| line_array[index]=1 if lines_hit.include?((index+1).to_s) }
      {filename => line_array}
    end

  end

end
