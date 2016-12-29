module Coverband
  module Reporters
    class Base

      def self.report(store, options = {})
        raise "abstract method child must implement"
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

      # [0,0,1,0,1]
      # [nil,0,1,0,0]
      # merge to
      # [0,0,1,0,1]
      def self.merge_arrays(first, second)
        merged = []
        longest = first.length > second.length ? first : second

        longest.each_with_index do |line, index|
          if first[index] || second[index]
            merged[index] = (first[index].to_i + second[index].to_i >= 1 ? 1 : 0)
          else
            merged[index] = nil
          end
        end

        merged
      end

      def self.merge_existing_coverage(scov_style_report, existing_coverage)
        existing_coverage.each_pair do |key, lines|
          if current_lines = scov_style_report[key]
            lines.each_with_index do |line, index|
              if line.nil? && current_lines[index].to_i == 0
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

      # > line_hash(store, 'hearno/script/tester.rb', ['/app/', '/Users/danmayer/projects/hearno/'])
      # {"/Users/danmayer/projects/hearno/script/tester.rb"=>[1, nil, 1, 1, nil, nil, nil]}
      def self.line_hash(store, key, roots)
        filename = filename_from_key(key, roots)
        if File.exists?(filename)

          count = File.foreach(filename).inject(0) { |c, line| c + 1 }
          if filename.match(/\.erb/)
            line_array = Array.new(count, nil)
          else
            line_array = Array.new(count, 0)
          end

          lines_hit = store.covered_lines_for_file(key)
          if lines_hit.is_a?(Array)
            line_array.each_with_index{|line,index| line_array[index] = 1 if lines_hit.include?((index + 1)) }
          else
            line_array.each_with_index{|line,index| line_array[index] += lines_hit[(index + 1).to_s].to_i if lines_hit.keys.include?((index + 1).to_s) }
          end
          {filename => line_array}
        else
          Coverband.configuration.logger.info "file #{filename} not found in project"
          nil
        end
      end

    end
  end
end

