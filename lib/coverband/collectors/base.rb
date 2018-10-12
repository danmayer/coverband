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
          raise 'select valid collector [trace, coverage]'
        end
      end

      def save
        report_coverage
      end

      def reset_instance
        @project_directory = File.expand_path(Coverband.configuration.root)
        @enabled = true
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
        @ignore_patterns.none? { |pattern| file.include?(pattern) } && file.start_with?(@project_directory)
      end

      def output_file_line_usage
        @logger.debug 'coverband debug coverband file:line usage:'
        @file_line_usage.sort_by { |_key, value| value.length }.each do |pair|
          file = pair.first
          lines = pair.last
          @logger.info "file: #{file} => #{lines}"
        end
      end

      private

      def failed_at_thread_key
        "__#{self.class.name}__failed_at"
      end

      def failed_at
        Thread.current[failed_at_thread_key]
      end

      def failed_at=(time)
        Thread.current[failed_at_thread_key] = time
      end

      def failed!
        self.failed_at = Time.now
      end

      def initialize
        reset_instance
      end
    end
  end
end
