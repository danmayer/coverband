# frozen_string_literal: true

module Coverband
  module Reporters
    ###
    # Console Report allows for simple reporting via the command line.
    ###
    class ConsoleReport < Base
      def self.report(store, options = {})
        coverband_reports = Coverband::Reporters::Base.report(store, options)
        fix_reports(coverband_reports)
        result = Coverband::Utils::Results.new(coverband_reports)
        source_files = result.source_files

        Coverband.configuration.logger.info "total_files: #{source_files.length}"
        Coverband.configuration.logger.info "lines_of_code: #{source_files.lines_of_code}"
        Coverband.configuration.logger.info "lines_covered: #{source_files.covered_lines}"
        Coverband.configuration.logger.info "lines_missed: #{source_files.missed_lines}"
        Coverband.configuration.logger.info "covered_percent: #{source_files.covered_percent}"

        coverband_reports[:merged].each_pair do |file, usage|
          Coverband.configuration.logger.info "#{file}: #{usage["data"]}"
        end
        coverband_reports
      end
    end
  end
end
