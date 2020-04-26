# frozen_string_literal: true

module Coverband
  module Reporters
    class HTMLReport < Base
      attr_accessor :filtered_report_files, :open_report, :notice,
        :base_path, :filename

      def initialize(store, options = {})
        coverband_reports = Coverband::Reporters::Base.report(store, options)
        self.open_report = options.fetch(:open_report) { true }
        # TODO: refactor notice out to top level of web only
        self.notice = options.fetch(:notice) { nil }
        self.base_path = options.fetch(:base_path) { './' }
        self.filename = options.fetch(:filename) { nil }

        self.filtered_report_files = self.class.fix_reports(coverband_reports)
      end

      def file_details
        Coverband::Utils::HTMLFormatter.new(filtered_report_files,
          base_path: base_path,
          notice: notice).format_source_file!(filename)
      end

      def report
        report_dynamic_html
      end

      def report_data
        report_dynamic_data
      end

      private

      def report_dynamic_html
        Coverband::Utils::HTMLFormatter.new(filtered_report_files,
          base_path: base_path,
          notice: notice).format_dynamic_html!
      end

      def report_dynamic_data
        Coverband::Utils::HTMLFormatter.new(filtered_report_files,
          base_path: base_path,
          notice: notice).format_dynamic_data!
      end
    end
  end
end
