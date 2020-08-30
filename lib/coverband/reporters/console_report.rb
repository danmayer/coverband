# frozen_string_literal: true

module Coverband
  module Reporters
    ###
    # Console Report allows for simple reporting via the command line.
    ###
    class ConsoleReport < Base
      def self.report(store, options = {})
        scov_style_report = super(store, options)
        scov_style_report[:merged].each_pair do |file, usage|
          Coverband.configuration.logger.info "#{file}: #{usage["data"]}"
        end
        scov_style_report
      end
    end
  end
end
