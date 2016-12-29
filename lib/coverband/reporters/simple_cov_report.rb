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

        roots = get_roots
        existing_coverage = Coverband.configuration.coverage_baseline
        open_report = options.fetch(:open_report) { true }

        if Coverband.configuration.verbose
          Coverband.configuration.logger.info "fixing root: #{roots.join(', ')}"
        end

        additional_scov_data = options.fetch(:additional_scov_data) { [] }
        if Coverband.configuration.verbose
          print additional_scov_data
        end

        report_scov(store, existing_coverage, additional_scov_data, roots, open_report)
      end

      private

      def self.get_current_scov_data_imp(store, roots)
        scov_style_report = {}

        ###
        # why do we need to merge covered files data?
        # basically because paths on machines or deployed hosts could be different, so
        # two different keys could point to the same filename or `line_key`
        # this logic should be pushed to base report
        ###
        store.covered_files.each do |key|
          next if Coverband.configuration.ignore.any?{ |i| key.match(i) }
          line_data = line_hash(store, key, roots)

          if line_data
            line_key = line_data.keys.first
            previous_line_hash = scov_style_report[line_key]

            if previous_line_hash
              line_data[line_key] = merge_arrays(line_data[line_key], previous_line_hash)
            end

            scov_style_report.merge!(line_data)
          end
        end

        scov_style_report = fix_file_names(scov_style_report, roots)
        scov_style_report
      end

      def self.report_scov_with_additional_data(store, existing_coverage, additional_scov_data, roots)
        scov_style_report = get_current_scov_data_imp(store, roots)
        existing_coverage = fix_file_names(existing_coverage, roots)
        scov_style_report = merge_existing_coverage(scov_style_report, existing_coverage)

        additional_scov_data.each do |data|
          scov_style_report = merge_existing_coverage(scov_style_report, data)
        end

        scov_style_report
      end

      def self.report_scov(store, existing_coverage, additional_scov_data, roots, open_report)
        scov_style_report = report_scov_with_additional_data(store, existing_coverage, additional_scov_data, roots)

        if Coverband.configuration.verbose
          Coverband.configuration.logger.info "report: "
          Coverband.configuration.logger.info scov_style_report.inspect
        end

        # add in files never hit in coverband
        SimpleCov.track_files "#{current_root}/{app,lib,config}/**/*.{rb,haml,erb,slim}"
        SimpleCov::Result.new(SimpleCov.add_not_loaded_files(scov_style_report)).format!

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

