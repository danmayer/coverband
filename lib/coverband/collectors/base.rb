# frozen_string_literal: true

####
# TODO refactor this if we only have one collector this could go away
####
module Coverband
  module Collectors
    class Base
      def self.instance
        if Coverband.configuration.collector == 'coverage'
          Thread.current[:coverband_instance] ||= Coverband::Collectors::Coverage.new
        else
          raise 'select valid collector [coverage]'
        end
      end

      def save
        report_coverage
      end

      def reset_instance
        @project_directory = File.expand_path(Coverband.configuration.root)
        @file_line_usage = {}
        @ignored_files = Set.new
        @ignore_patterns = Coverband.configuration.ignore + ['internal:prelude', 'schema.rb']
        @reporting_frequency = Coverband.configuration.reporting_frequency
        @store = Coverband.configuration.store
        @verbose  = Coverband.configuration.verbose
        @logger   = Coverband.configuration.logger
        @current_thread = Thread.current
        Thread.current[:coverband_instance] = nil
        self
      end

      def report_coverage
        raise 'abstract'
      end

      protected

      def track_file?(file)
        @ignore_patterns.none? do |pattern|
          file.include?(pattern)
        end && file.start_with?(@project_directory)
      end

      private

      def initialize
        reset_instance
      end
    end
  end
end
