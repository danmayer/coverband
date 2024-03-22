# frozen_string_literal: true

# Outputs data in json format similar to what is shown in the HTML page
# Top level and file level coverage numbers
module Coverband
  module Reporters
    class JSONReport < Base
      attr_accessor :filtered_report_files, :options, :page, :as_report, :store, :filename, :base_path

      def initialize(store, options = {})
        self.options = options
        self.page = options.fetch(:page) { nil }
        self.filename = options.fetch(:filename) { nil }
        self.as_report = options.fetch(:as_report) { false }
        self.base_path = options.fetch(:base_path) { "./" }
        self.store = store

        coverband_reports = Coverband::Reporters::Base.report(store, options)
        # NOTE: paged reports can't find and add in files that has never been loaded
        self.filtered_report_files = if page || filename
          coverband_reports
        else
          self.class.fix_reports(coverband_reports)
        end
      end

      def report
        report_as_json
      end

      private

      def coverage_css_class(covered_percent)
        if covered_percent.nil?
          ""
        elsif covered_percent > 90
          "green"
        elsif covered_percent > 80
          "yellow"
        else
          "red"
        end
      end

      def report_as_json
        result = Coverband::Utils::Results.new(filtered_report_files)
        source_files = result.source_files

        data = {
          **coverage_totals(source_files),
          files: coverage_files(result, source_files)
        }

        if as_report
          row_data = []
          data[:files].each_pair do |key, data|
            source_class = data[:never_loaded] ? 'strong red' : 'strong'
            data_loader_url = "#{base_path}load_file_details?filename=#{data[:filename]}"
            link = "<a href=\"##{data[:hash]}\" class=\"src_link #{source_class} cboxElement\" title=\"#{key}\" data-loader-url=\"#{data_loader_url}\" onclick=\"src_link_click(this)\">#{key}</a>"
            runtime_percentage = "<span class=\"#{coverage_css_class(data[:runtime_percentage])}\">#{data[:runtime_percentage]}</span>"
            covered_percent = "<span class=\"#{coverage_css_class(data[:covered_percent])}\">#{data[:covered_percent]}</span>"
            row_data << [
              link,
              covered_percent,
              runtime_percentage,
              data[:lines_of_code].to_s,
              (data[:lines_covered] + data[:lines_missed]).to_s,
              data[:lines_covered].to_s,
              data[:lines_runtime].to_s,
              data[:lines_missed].to_s,
              data[:covered_strength].to_s
            ]
          end
          filesreported = store.file_count(:runtime)
          data["iTotalRecords"] = filesreported
          data["iTotalDisplayRecords"] = filesreported
          data["aaData"] = row_data
          data.delete(:files)
          data = data.as_json
        end
        data.to_json
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
          runtime_coverage = result.file_with_type(source_file, Coverband::RUNTIME_TYPE)&.covered_lines_count || 0
          hash[source_file.short_name] = {
            filename: source_file.filename,
            hash: Digest::SHA1.hexdigest(source_file.filename),
            never_loaded: source_file.never_loaded,
            runtime_percentage: result.runtime_relevant_coverage(source_file),
            lines_of_code: source_file.lines.count,
            lines_covered: source_file.covered_lines.count,
            lines_runtime: runtime_coverage,
            lines_missed: source_file.missed_lines.count,
            covered_percent: source_file.covered_percent,
            covered_strength: source_file.covered_strength
          }
        end
      end
    end
  end
end
