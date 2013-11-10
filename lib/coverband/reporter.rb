require 'simplecov'

module Coverband

  class Reporter

    def self.baseline
      require 'coverage'
      Coverage.start
      yield
      @project_directory = File.expand_path(Dir.pwd)
      results = Coverage.result
      results = results.reject{|key, val| !key.match(@project_directory)}
      puts results.inspect
      
      File.open('./tmp/coverband_baseline.json', 'w') {|f| f.write(results.to_json) }
    end

    def self.report(redis, options = {})
      roots = options.fetch(:roots){[]}
      existing_coverage = options.fetch(:existing_coverage){ {} }
      roots << "#{File.expand_path(Dir.pwd)}/"
      puts "fixing root: #{roots.join(', ')}"
      if options.fetch(:reporter){ 'rcov' }=='rcov'
        report_rcov(redis, existing_coverage, roots)
      else
        redis.smembers('coverband').each{|key| report_line(redis, key) }
      end
    end

    private

    def self.fix_file_names(report_hash, roots)
      fixed_report = {} #normalize names across servers
      report_hash.each_pair do |key, values| 
        filename = filename_from_key(key, roots)
        fixed_report[filename] = values
      end
      fixed_report
    end

    def self.report_rcov(redis, existing_coverage, roots)
      rcov_style_report = {}
      redis.smembers('coverband').each{|key| line_data = line_hash(redis, key, roots); rcov_style_report.merge!(line_data) if line_data }
      rcov_style_report = fix_file_names(rcov_style_report, roots)
      existing_coverage = fix_file_names(existing_coverage, roots)
      rcov_style_report = merge_existing_coverage(rcov_style_report, existing_coverage)
      puts "report: "
      puts rcov_style_report.inspect
      SimpleCov::Result.new(rcov_style_report).format!
      `open coverage/index.html`
    end

    def self.merge_existing_coverage(rcov_style_report, existing_coverage)
      existing_coverage.each_pair do |key, lines|
        if current_lines = rcov_style_report[key]
          lines.each_with_index do |line, index|
            if line.nil? && current_lines[index].to_i==0
              current_lines[index] = nil
            else
              current_lines[index] = current_lines[index] ? (current_lines[index].to_i + line.to_i) : nil
            end
          end
          rcov_style_report[key] = current_lines
        else
          rcov_style_report[key] = lines
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

    def self.filename_from_key(key, roots)
      filename = key.gsub('.','/').gsub('//','./').gsub('/rb','.rb').gsub('/erb','.erb')
      roots.each do |root|
        filename = filename.gsub(root, './')
      end
      filename = filename.gsub('./', roots.last)
      filename
    end

    # >> puts  Coverage.result.inspect
    # {"/Users/danmayer/projects/hearno/script/tester.rb"=>[1, nil, 1, 1, nil, nil, nil]}
    def self.line_hash(redis, key, roots)
      filename = filename_from_key(key, roots)
      if File.exists?(filename)
        lines_hit = redis.smembers("coverband#{key}")
        count = File.foreach(filename).inject(0) {|c, line| c+1}
        if filename.match(/\.erb/)
          line_array = Array.new(count, nil)
        else
          line_array = Array.new(count, 0)
        end
        line_array.each_with_index{|line,index| line_array[index]=1 if lines_hit.include?((index+1).to_s) }
        {filename => line_array}
      else
        puts "file #{filename} not found in project"
      end
    end

  end

end
