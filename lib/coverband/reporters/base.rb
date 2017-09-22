module Coverband
  module Reporters
    class Base

      def self.report(store, options = {})
        roots = get_roots
        additional_coverage_data = options.fetch(:additional_scov_data) { [] }

        if Coverband.configuration.verbose
          Coverband.configuration.logger.info "fixing root: #{roots.join(', ')}"
          Coverband.configuration.logger.info "additional data:\n #{additional_coverage_data}"
        end

        scov_style_report = report_scov_with_additional_data(store, additional_coverage_data, roots)

        if Coverband.configuration.verbose
          Coverband.configuration.logger.info "report:\n #{scov_style_report.inspect}"
        end
        scov_style_report
      end

      def self.get_roots
        roots = Coverband.configuration.root_paths
        roots << "#{current_root}/"
        roots
      end

      def self.current_root
        File.expand_path(Coverband.configuration.root)
      end

      protected

      def self.fix_file_names(report_hash, roots)
        fixed_report = {} #normalize names across servers
        report_hash.each_pair do |key, values|
          filename = filename_from_key(key, roots)
          fixed_report[filename] = values
        end
        fixed_report
      end

      # > merge_arrays([0,0,1,0,1],[nil,0,1,0,0])
      # [0,0,1,0,1]
      def self.merge_arrays(first, second)
        merged = []
        longest = first.length > second.length ? first : second

        longest.each_with_index do |line, index|
          if first[index] || second[index]
            merged[index] = (first[index].to_i + second[index].to_i)
          else
            merged[index] = nil
          end
        end

        merged
      end

      # > merge_existing_coverage({"file.rb" => [0,1,2,nil,nil,nil]}, {"file.rb" => [0,1,2,nil,0,1,2]})
      # expects = {"file.rb" => [0,2,4,nil,0,1,2]}
      def self.merge_existing_coverage(scov_style_report, existing_coverage)
        existing_coverage.each_pair do |file_key, existing_lines|
          next if Coverband.configuration.ignore.any?{ |i| file_key.match(i) }
          if current_line_hits = scov_style_report[file_key]
            scov_style_report[file_key] = merge_arrays(current_line_hits, existing_lines)
          else
            scov_style_report[file_key] = existing_lines
          end
        end
        scov_style_report
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

      def self.track_line?(line)
        # empty lines
        return false if line.match(/^$/).present?

        # comments
        return false if line.match(/^[\s\t]*#/).present?

        # irrelevant lines
        lines_to_skip = ['require', 'include', 'def', 'class', 'module', 'end', 'private', 'public',
          'load_and_authorize_resource', 'layout', 'protect_from_forgery']
        return false if line.match(/^[(?:\t{0,3}|\s{0,3}]*(?:#{lines_to_skip.join('|')})(?:\s|$)/).present?

        # constant definitions
        # return false if line.match(/^[\s]*[A-Z_][A-Z_]+[\s]*=/).present?
        true
      end

      # > line_hash(store, 'hearno/script/tester.rb', ['/app/', '/Users/danmayer/projects/hearno/'])
      # {"/Users/danmayer/projects/hearno/script/tester.rb"=>[1, nil, 1, 2, nil, nil, nil]}
      def self.line_hash(store, key, roots)
        filename = filename_from_key(key, roots)
        if File.exists?(filename)
          line_array = Array.new
          File.foreach(filename).inject(0) do |_, line|
            if track_line?(line)
              line_array << 0
            else
              line_array << nil
            end
          end

          lines_hit = store.covered_lines_for_file(key)
          if lines_hit.is_a?(Array)
            line_array.each_with_index{|_,index| line_array[index] = 1 if lines_hit.include?((index + 1)) }
          else
            line_array.each_with_index{|_,index| line_array[index] = (line_array[index].to_i + lines_hit[(index + 1).to_s].to_i) if lines_hit.keys.include?((index + 1).to_s) }
          end
          {filename => line_array}
        else
          Coverband.configuration.logger.info "file #{filename} not found in project"
          nil
        end
      end

      def self.get_current_scov_data_imp(store, roots)
        scov_style_report = {}

        ###
        # why do we need to merge covered files data?
        # basically because paths on machines or deployed hosts could be different, so
        # two different keys could point to the same filename or `line_key`
        # this logic should be pushed to base report
        ###
        store.covered_files.each do |key|
          next if Coverband.configuration.ignore.any?{ |i| key.match(i) }
          line_data = line_hash(store, key, roots)

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
        scov_style_report
      end

      def self.report_scov_with_additional_data(store, additional_scov_data, roots)
        scov_style_report = get_current_scov_data_imp(store, roots)

        additional_scov_data.each do |data|
          scov_style_report = merge_existing_coverage(scov_style_report, data)
        end

        scov_style_report
      end

    end
  end
end

