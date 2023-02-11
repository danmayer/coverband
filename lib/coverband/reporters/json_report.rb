# frozen_string_literal: true

# Outputs data in json format similar to what is shown in the HTML page
# Top level and file level coverage numbers
module Coverband
  module Reporters
    class JSONReport < Base
      attr_accessor :filtered_report_files

      def initialize(store, options = {})
        coverband_reports = Coverband::Reporters::Base.report(store, options)
        self.filtered_report_files = self.class.fix_reports(coverband_reports)
      end

      def report
        report_as_json
      end

      private

      def report_as_json
        result = Coverband::Utils::Results.new(filtered_report_files)
        source_files = result.source_files
        {
          **coverage_totals(source_files),
          files: coverage_files(result, source_files)
        }.to_json
      end

      def coverage_totals(source_files)
        {
          total_files: source_files.length,
          lines_of_code: source_files.lines_of_code,
          lines_covered: source_files.covered_lines,
          lines_missed: source_files.missed_lines,
          covered_strength: source_files.covered_strength,
          covered_percent: source_files.covered_percent
        }
      end

      # Using a hash indexed by file name for quick lookups
      def coverage_files(result, source_files)
        source_files.each_with_object({}) do |source_file, hash|
          hash[source_file.short_name] = {
            never_loaded: source_file.never_loaded,
            runtime_percentage: result.runtime_relevant_coverage(source_file),
            lines_of_code: source_file.lines.count,
            lines_covered: source_file.covered_lines.count,
            lines_missed: source_file.missed_lines.count,
            covered_percent: source_file.covered_percent,
            covered_strength: source_file.covered_strength
          }
        end
      end
    end
  end
end
