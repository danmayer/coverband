# frozen_string_literal: true

module Coverband
  module Reporters
    class HTMLReport < Base
      attr_accessor :filtered_report_files, :open_report, :notice,
        :base_path, :filename, :page

      def initialize(store, options = {})
        self.page = options.fetch(:page) { nil }
        self.open_report = options.fetch(:open_report) { true }
        # TODO: refactor notice out to top level of web only
        self.notice = options.fetch(:notice) { nil }
        self.base_path = options.fetch(:base_path) { "./" }
        self.filename = options.fetch(:filename) { nil }

        coverband_reports = Coverband::Reporters::Base.report(store, options)
        # NOTE: at the moment the optimization around paging and filenames only works for hash redis store
        self.filtered_report_files = if (page || filename) && store.is_a?(Coverband::Adapters::HashRedisStore)
          coverband_reports
        else
          self.class.fix_reports(coverband_reports)
        end
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
          notice: notice,
          page: page).format_dynamic_html!
      end

      def report_dynamic_data
        Coverband::Utils::HTMLFormatter.new(filtered_report_files,
          base_path: base_path,
          page: page,
          notice: notice).format_dynamic_data!
      end
    end
  end
end
