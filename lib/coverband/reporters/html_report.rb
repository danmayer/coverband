# frozen_string_literal: true

module Coverband
  module Reporters
    class HTMLReport < Base
      def self.report(store, options = {})
        coverband_reports = super(store, options)
        open_report = options.fetch(:open_report) { true }
        html = options.fetch(:html) { false }
        # TODO: refactor notice out to top level of web only
        notice = options.fetch(:notice) { nil }
        base_path = options.fetch(:base_path) { nil }

        filtered_report_files = fix_reports(coverband_reports)
        if html
          Coverband::Utils::HTMLFormatter.new(filtered_report_files,
                                              base_path: base_path,
                                              notice: notice).format_html!
        else
          Coverband::Utils::HTMLFormatter.new(filtered_report_files).format!
          if open_report
            `open #{Coverband.configuration.root}/coverage/index.html`
          else
            Coverband.configuration.logger.info 'report is ready and viewable: open coverage/index.html'
          end

          Coverband::Utils::S3Report.instance.persist! if Coverband.configuration.s3_bucket
        end
      end

      def self.fix_reports(reports)
        # list all files, even if not tracked by Coverband (0% coverage)
        tracked_glob = "#{Coverband.configuration.current_root}/{app,lib,config}/**/*.{rb}"
        filtered_report_files = {}

        reports.each_pair do |report_name, report_data|
          filtered_report_files[report_name] = {}
          report_files = Coverband::Utils::Result.add_not_loaded_files(report_data, tracked_glob)

          # apply coverband filters
          report_files.each_pair do |file, data|
            next if Coverband.configuration.ignore.any? { |i| file.match(i) }

            filtered_report_files[report_name][file] = data
          end
        end
      end
    end
  end
end
