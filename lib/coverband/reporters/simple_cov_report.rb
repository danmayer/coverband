module Coverband
  module Reporters
    class SimpleCovReport < Base

      #TODO almost all of this can move to base for getting a scov style report with baseline and additional coverage merged.
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

        additional_coverage_data = options.fetch(:additional_scov_data) { [] }
        if Coverband.configuration.verbose
          Coverband.configuration.logger.info "additional data:\n #{additional_coverage_data}"
        end
        additional_coverage_data.push(fix_file_names(existing_coverage, roots))

        scov_style_report = report_scov_with_additional_data(store, additional_coverage_data, roots)

        if Coverband.configuration.verbose
          Coverband.configuration.logger.info "report:\n #{scov_style_report.inspect}"
        end

        # add in files never hit in coverband
        SimpleCov.track_files "#{current_root}/{app,lib,config}/**/*.{rb,haml,erb,slim}"
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

      def self.report_scov_with_additional_data(store, additional_scov_data, roots)
        scov_style_report = get_current_scov_data_imp(store, roots)

        additional_scov_data.each do |data|
          scov_style_report = merge_existing_coverage(scov_style_report, data)
        end

        scov_style_report
      end

    end
  end
end

