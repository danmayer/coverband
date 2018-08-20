# frozen_string_literal: true

module Coverband
  module Reporters
    class SimpleCovReport < Base

      def self.normalize_scov_report(report)
        report.inject({}) do |mem, (file, cover_hits)|
          mem.merge(
              { file => (
              scov = SimpleCov::LinesClassifier.new.classify(File.foreach(file))
              cover_hits.map.with_index { |cover_hits, ind| cover_hits.to_i + scov[ind] unless scov[ind].nil? }
              ) }
          )
        end
      end

      def self.report(store, options = {})
        begin
          require 'simplecov'
        rescue StandardError
          Coverband.configuration.logger.error 'coverband requires simplecov in order to generate a report, when configured for the scov report style.'
          return
        end

        scov_style_report = normalize_scov_report(super(store, options))

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
          next if Coverband.configuration.ignore.any? { |i| file.match(i) }
          filtered_report_files[file] = data
        end

        SimpleCov::Result.new(filtered_report_files).format!

        if open_report
          `open #{SimpleCov.coverage_dir}/index.html`
        else
          Coverband.configuration.logger.info "report is ready and viewable: open #{SimpleCov.coverage_dir}/index.html"
        end

        s3_writer_options = {
            region: Coverband.configuration.s3_region,
            access_key_id: Coverband.configuration.s3_access_key_id,
            secret_access_key: Coverband.configuration.s3_secret_access_key
        }
        S3ReportWriter.new(Coverband.configuration.s3_bucket, s3_writer_options).persist! if Coverband.configuration.s3_bucket
      end
    end
  end
end
