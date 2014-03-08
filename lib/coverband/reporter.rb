require 'simplecov'

module Coverband
  class Reporter

    def self.baseline
      require 'coverage'
      Coverage.start
      yield
      @project_directory = File.expand_path(Coverband.configuration.root)
      results = Coverage.result
      results = results.reject{|key, val| !key.match(@project_directory) || Coverband.configuration.ignore.any?{|pattern| key.match(/#{pattern}/)} }
      puts results.inspect
      
      File.open('./tmp/coverband_baseline.json', 'w') {|f| f.write(results.to_json) }
    end

    def self.report
      redis = Coverband.configuration.redis
      roots = Coverband.configuration.root_paths
      existing_coverage = Coverband.configuration.coverage_baseline
      roots << "#{current_root}/"
      puts "fixing root: #{roots.join(', ')}"
      if  Coverband.configuration.reporter=='scov'
        report_scov(redis, existing_coverage, roots)
      else
        lines = redis.smembers('coverband').map{|key| report_line(redis, key) }
        puts lines.join("\n")
      end
    end

    def self.clear_coverage(redis = nil)
      redis ||= Coverband.configuration.redis
      redis.smembers('coverband').each{|key| redis.del("coverband.#{key}")}
    end

    def self.current_root
      File.expand_path(Coverband.configuration.root)
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

    def self.report_scov(redis, existing_coverage, roots)
      scov_style_report = {}
      redis.smembers('coverband').each{|key| line_data = line_hash(redis, key, roots); scov_style_report.merge!(line_data) if line_data }
      scov_style_report = fix_file_names(scov_style_report, roots)
      existing_coverage = fix_file_names(existing_coverage, roots)
      scov_style_report = merge_existing_coverage(scov_style_report, existing_coverage)
      puts "report: "
      puts scov_style_report.inspect
      SimpleCov::Result.new(scov_style_report).format!
      puts "report is ready and viewable: open #{SimpleCov.coverage_dir}/index.html"
    end

    def self.merge_existing_coverage(scov_style_report, existing_coverage)
      existing_coverage.each_pair do |key, lines|
        if current_lines = scov_style_report[key]
          lines.each_with_index do |line, index|
            if line.nil? && current_lines[index].to_i==0
              current_lines[index] = nil
            else
              current_lines[index] = current_lines[index] ? (current_lines[index].to_i + line.to_i) : nil
            end
          end
          scov_style_report[key] = current_lines
        else
          scov_style_report[key] = lines
        end
      end
      scov_style_report
    end

    # /Users/danmayer/projects/cover_band_server/views/index/erb: ["0", "2", "3", "6", "65532", "65533"]
    # /Users/danmayer/projects/cover_band_server/app/rb: ["54", "55"]
    # /Users/danmayer/projects/cover_band_server/views/layout/erb: ["0", "33", "36", "37", "38", "39", "40", "62", "63", "66", "65532", "65533"]
    def self.report_line(redis, key)
      "#{key}: #{redis.smembers("coverband.#{key}").inspect}"
    end

    def self.filename_from_key(key, roots)
      filename = key
      roots.each do |root|
        filename = filename.gsub(/^#{root}/, './')
      end
      filename = filename.gsub('./', roots.last)
      filename
    end

    # >> puts  Coverage.result.inspect
    # {"/Users/danmayer/projects/hearno/script/tester.rb"=>[1, nil, 1, 1, nil, nil, nil]}
    def self.line_hash(redis, key, roots)
      filename = filename_from_key(key, roots)
      if File.exists?(filename)
        lines_hit = redis.smembers("coverband.#{key}")
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
