module Coverband
  module Adapters
    class FileStore
      attr_accessor :path

      def initialize(path, opts = {})
        @path = path

        config_dir = File.dirname(@path)
        Dir.mkdir config_dir unless File.exist?(config_dir)
      end

      def clear!
        if File.exist?(path)
          File.delete(path)
        end
      end

      def save_report(report)
        results = existing_data(path)
        report.each_pair do |file, values|
          if results.has_key?(file)
            # convert the keys to "3" opposed to 3
            values = JSON.parse(values.to_json)
            results[file].merge!( values ){|k, old_v, new_v| old_v.to_i + new_v.to_i}
          else
            results[file] = values
          end
        end
        File.open(path, 'w') { |f| f.write(results.to_json) }
      end

      def coverage
        existing_data(path)
      end

      def covered_files
        report = existing_data(path)
        existing_data(path).merge(report).keys || []
      end

      def covered_lines_for_file(file)
        report = existing_data(path)
        report[file] || []
      end

      private

      def existing_data(path)
        if File.exist?(path)
          JSON.parse(File.read(path))
        else
          {}
        end
      end

    end
  end
end
