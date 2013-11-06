require 'simplecov'

module Coverband

  class Reporter
    
    def self.report(redis, options = {})
      if options.fetch(:reporter){ 'rcov' }=='rcov'
        report_rcov(redis, options['existing_coverage'])
      else
        redis.smembers('coverband').each{|key| report_line(redis, key) }
      end
    end

    private

    def self.report_rcov(redis, existing_coverage)
      rcov_style_report = {}
      redis.smembers('coverband').each{|key| rcov_style_report.merge!(line_hash(redis, key)) }
      rcov_style_report = merge_existing_coverage(rcov_style_report, existing_coverage)
      puts "report:"
      puts rcov_style_report.inspect
      SimpleCov::Result.new(rcov_style_report).format!
      `open coverage/index.html`
    end

    def self.merge_existing_coverage(rcov_style_report, existing_coverage)
      existing_coverage.each_pair do |key, lines|
        if current_lines = rcov_style_report[key]
          lines.each_with_index do |line, index|
            current_lines[index] = current_lines[index] ? (current_lines[index].to_i + line.to_i) : nil 
          end
          rcov_style_report[key] = current_lines
        end
      end
      rcov_style_report
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
      line_array.each_with_index{|line,index| line_array[index]=1 if lines_hit.include?((index+1).to_s) }
      {filename => line_array}
    end

  end

end
