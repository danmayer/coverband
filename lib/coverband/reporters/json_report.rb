# frozen_string_literal: true

# Outputs data in json format similar to what is shown in the HTML page
# Top level and file level coverage numbers
module Coverband
  module Reporters
    class JSONReport < Base
      attr_accessor :filtered_report_files, :options, :page, :as_report, :store, :filename, :base_path, :line_coverage,
        :for_merged_report

      def initialize(store, options = {})
        self.options = options
        self.page = options.fetch(:page) { nil }
        self.filename = options.fetch(:filename) { nil }
        self.as_report = options.fetch(:as_report) { false }
        self.line_coverage = options.fetch(:line_coverage) { false }
        self.for_merged_report = options.fetch(:for_merged_report) { false }
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

      def merge_reports(first_report, second_report, options = {})
        merged_data = {}
        merged_data[Coverband::RUNTIME_TYPE.to_s] = Coverband::Adapters::Base.new.send(
          :merge_reports,
          first_report[Coverband::RUNTIME_TYPE.to_s],
          second_report[Coverband::RUNTIME_TYPE.to_s],
          {skip_expansion: true}
        )
        if first_report[Coverband::EAGER_TYPE.to_s] && second_report[Coverband::EAGER_TYPE.to_s]
          merged_data[Coverband::EAGER_TYPE.to_s] = Coverband::Adapters::Base.new.send(
            :merge_reports,
            first_report[Coverband::EAGER_TYPE.to_s],
            second_report[Coverband::EAGER_TYPE.to_s],
            {skip_expansion: true}
          )
        end
        if first_report[Coverband::MERGED_TYPE.to_s] && second_report[Coverband::MERGED_TYPE.to_s]
          merged_data[Coverband::MERGED_TYPE.to_s] = Coverband::Adapters::Base.new.send(
            :merge_reports,
            first_report[Coverband::MERGED_TYPE.to_s],
            second_report[Coverband::MERGED_TYPE.to_s],
            {skip_expansion: true}
          )
        end
        merged_data
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
        return filtered_report_files.to_json if for_merged_report

        result = Coverband::Utils::Results.new(filtered_report_files)
        source_files = result.source_files

        data = {
          **coverage_totals(source_files),
          files: coverage_files(result, source_files)
        }

        if as_report
          row_data = []
          data[:files].each_pair do |key, data|
            source_class = data[:never_loaded] ? "strong red" : "strong"
            data_loader_url = "#{base_path}load_file_details?filename=#{data[:filename]}"
            link = "<a href=\"##{data[:hash]}\" class=\"src_link #{source_class} cboxElement\" title=\"#{key}\" data-loader-url=\"#{data_loader_url}\" onclick=\"src_link_click(this)\">#{key}</a>"
            # Hack to ensure the sorting works on percentage columns, the span is hidden but colors the cell and the text is used for sorting
            covered_percent = "#{data[:covered_percent]} <span class=\"#{coverage_css_class(data[:covered_percent])}\">&nbsp;</span>"
            runtime_percentage = "#{data[:runtime_percentage]}<span class=\"#{coverage_css_class(data[:runtime_percentage])}\">&nbsp;</span>"
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
          filesreported = store.cached_file_count
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
          data = {
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
          data[:coverage] = source_file.coverage if line_coverage
          hash[source_file.short_name] = data
        end
      end
    end
  end
end
