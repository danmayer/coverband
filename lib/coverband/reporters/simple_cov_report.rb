module Coverband
  module Reporters
    class SimpleCovReport < Base

      def self.report(store, options = {})
        begin
          require 'simplecov'
        rescue
          Coverband.configuration.logger.error "coverband requires simplecov in order to generate a report, when configured for the scov report style."
          return
        end

        scov_style_report = super(store, options)

        open_report = options.fetch(:open_report) { true }

        # set root to show files if user has simplecov profiles
        # https://github.com/danmayer/coverband/issues/59
        SimpleCov.root(current_root)

        # add in files never hit in coverband
        SimpleCov.track_files "#{current_root}/{app,lib,config}/**/*.{rb,haml,erb,slim}"

        # still apply coverband filters
        report_files = SimpleCov.add_not_loaded_files(scov_style_report)
        filtered_report_files = {}
        report_files.each_pair do |file, data|
          next if Coverband.configuration.ignore.any?{ |i| file.match(i) }
          filtered_report_files[file] = data
        end

        SimpleCov::Result.new(filtered_report_files).format!

        if open_report
          `open #{SimpleCov.coverage_dir}/index.html`
        else
          Coverband.configuration.logger.info "report is ready and viewable: open #{SimpleCov.coverage_dir}/index.html"
        end

        S3ReportWriter.new(Coverband.configuration.s3_bucket).persist! if Coverband.configuration.s3_bucket
      end

    end
  end
end

