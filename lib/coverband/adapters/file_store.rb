module Coverband
  module Adapters
    class FileStore
      attr_accessor :path

      def initialize(path, opts = {})
        @path = path
      end

      def clear!
        if File.exist?(path)
          File.delete(path)
        end
      end

      def save_report(report)
        results = existing_data(path).merge(report)
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
