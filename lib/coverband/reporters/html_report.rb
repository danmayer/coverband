# frozen_string_literal: true

module Coverband
  module Reporters
    class HTMLReport < Base
      def self.report(store, options = {})
        scov_style_report = super(store, options)
        open_report = options.fetch(:open_report) { true }
        html = options.fetch(:html) { false }

        # list all files, even if not tracked by Coverband (0% coverage)
        tracked_glob = "#{current_root}/{app,lib,config}/**/*.{rb}"
        report_files = Coverband::Utils::Result.add_not_loaded_files(scov_style_report, tracked_glob)
        # apply coverband filters
        filtered_report_files = {}
        report_files.each_pair do |file, data|
          next if Coverband.configuration.ignore.any? { |i| file.match(i) }
          filtered_report_files[file] = data
        end

        if html
          Coverband::Utils::HTMLFormatter.new(filtered_report_files).format_html!
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
    end
  end
end
