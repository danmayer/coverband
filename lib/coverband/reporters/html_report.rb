# frozen_string_literal: true

module Coverband
  module Reporters
    class HTMLReport < Base
      attr_accessor :filtered_report_files, :open_report, :static, :notice,
                    :base_path, :filename

      def initialize(store, options = {})
        coverband_reports = Coverband::Reporters::Base.report(store, options)
        self.open_report = options.fetch(:open_report) { true }
        self.static = options.fetch(:static) { true }
        # TODO: refactor notice out to top level of web only
        self.notice = options.fetch(:notice) { nil }
        self.base_path = options.fetch(:base_path) { nil }
        self.filename = options.fetch(:filename) { nil }

        self.filtered_report_files = self.class.fix_reports(coverband_reports)
      end

      def file_details
        Coverband::Utils::HTMLFormatter.new(filtered_report_files,
                                            base_path: base_path,
                                            notice: notice).format_source_file!(filename)
      end

      def report
        if static?
          report_static_site
        else
          report_dynamic_html
        end
      end

      private

      def static?
        static
      end

      def report_static_site
        Coverband::Utils::HTMLFormatter.new(filtered_report_files).format_static_html!
        if open_report
          `open #{Coverband.configuration.root}/coverage/index.html`
        else
          Coverband.configuration.logger.info 'report is ready and viewable: open coverage/index.html'
        end

        Coverband::Utils::S3Report.instance.persist! if Coverband.configuration.s3_bucket
      end

      def report_dynamic_html
        Coverband::Utils::HTMLFormatter.new(filtered_report_files,
                                            base_path: base_path,
                                            notice: notice).format_dynamic_html!
      end
    end
  end
end
