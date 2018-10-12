# frozen_string_literal: true

module Coverband
  module Adapters
    ###
    # Filesote store a merged coverage file to local disk
    # Generally this is for testing and development
    # Not recommended for production deployment
    ###
    class FileStore < Base
      attr_accessor :path

      def initialize(path, _opts = {})
        @path = path

        config_dir = File.dirname(@path)
        Dir.mkdir config_dir unless File.exist?(config_dir)
      end

      def clear!
        File.delete(path) if File.exist?(path)
      end

      def save_report(report)
        merge_reports(report, coverage)
        save_coverage(report)
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

      def save_coverage(report)
        File.open(path, 'w') { |f| f.write(report.to_json) }
      end

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
