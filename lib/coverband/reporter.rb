module Coverband
  class Reporter

    def self.baseline
      require 'coverage'
      Coverage.start
      yield
      @project_directory = File.expand_path(Coverband.configuration.root)
      results = Coverage.result
      results = results.reject{|key, val| !key.match(@project_directory) || Coverband.configuration.ignore.any?{|pattern| key.match(/#{pattern}/)} }

      if Coverband.configuration.verbose
        Coverband.configuration.logger.info results.inspect
      end
      
      File.open(Coverband.configuration.baseline_file, 'w') {|f| f.write(results.to_json) }
    end

    def self.report(options = {})
      begin
        require 'simplecov' if Coverband.configuration.reporter=='scov'
      rescue
        Coverband.configuration.logger.error "coverband requires simplecov in order to generate a report, when configured for the scov report style."
        return
      end
      redis = Coverband.configuration.redis
      roots = Coverband.configuration.root_paths
      existing_coverage = Coverband.configuration.coverage_baseline
      open_report = options.fetch(:open_report){ true }

      roots << "#{current_root}/"

      if Coverband.configuration.verbose
        Coverband.configuration.logger.info "fixing root: #{roots.join(', ')}"
      end

      if  Coverband.configuration.reporter=='scov'
        report_scov(redis, existing_coverage, roots, open_report)
      else
        lines = redis.smembers('coverband').map{|key| report_line(redis, key) }
        Coverband.configuration.logger.info lines.join("\n")
      end
    end

    def self.clear_coverage(redis = nil)
      redis ||= Coverband.configuration.redis
      redis.smembers('coverband').each{|key| redis.del("coverband.#{key}")}
      redis.del("coverband")
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

    # [0,0,1,0,1]
    # [nil,0,1,0,0]
    # merge to
    # [0,0,1,0,1]
    def self.merge_arrays(first, second)
      merged = []
      longest = if first.length > second.length 
        first
      else
        second
      end
     longest.each_with_index do |line, index|
              if first[index] || second[index]
                merged[index] = (first[index].to_i + second[index].to_i >= 1 ? 1 : 0)
              else
                merged[index] = nil
              end
            end
     merged
    end

    def self.report_scov(redis, existing_coverage, roots, open_report)
      scov_style_report = {}
      redis.smembers('coverband').each do |key|
                                   next if Coverband.configuration.ignore.any?{ |i| key.match(i)}
                                   line_data = line_hash(redis, key, roots)
                                   
                                   if line_data
                                     line_key = line_data.keys.first
                                     previous_line_hash = scov_style_report[line_key]
                                     if previous_line_hash
                       
                                       line_data[line_key] = merge_arrays(line_data[line_key], previous_line_hash)
                                     end
                                     scov_style_report.merge!(line_data)
                                   end
                                 end
      scov_style_report = fix_file_names(scov_style_report, roots)
      existing_coverage = fix_file_names(existing_coverage, roots)
      scov_style_report = merge_existing_coverage(scov_style_report, existing_coverage)
      
      if Coverband.configuration.verbose
        Coverband.configuration.logger.info "report: "
        Coverband.configuration.logger.info scov_style_report.inspect
      end
      
      SimpleCov::Result.new(scov_style_report).format!
      if open_report
        `open #{SimpleCov.coverage_dir}/index.html`
      else
        Coverband.configuration.logger.info "report is ready and viewable: open #{SimpleCov.coverage_dir}/index.html"
      end
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
      "#{key}: #{redis.smembers("coverband.#{key}").inspect}" #" fix line styles
    end

    def self.filename_from_key(key, roots)
      filename = key
      roots.each do |root|
        filename = filename.gsub(/^#{root}/, './')
      end
      # the filename for  SimpleCov is expected to be a full path.
      # roots.last should be roots << current_root}/
      # a fully expanded path of config.root
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
        Coverband.configuration.logger.info "file #{filename} not found in project"
        nil
      end
    end

  end
end
