module Coverband
  module Reporters
    class ConsoleReport < Base

      def self.report(store, options = {})
        roots = get_roots
        #todo console should merge in baseline
        existing_coverage = Coverband.configuration.coverage_baseline
        #puts existing_coverage


        if Coverband.configuration.verbose
          Coverband.configuration.logger.info "fixing root: #{roots.join(', ')}"
        end

        report = store.coverage_report
        report.each_pair do |file, usage|
          Coverband.configuration.logger.info "#{file}: #{usage}"
        end
        report
      end

    end
  end
end

