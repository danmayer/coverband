# frozen_string_literal: true

####
# TODO refactor this along with the coverage and trace collector
####
module Coverband
  module Collectors
    class Base
      def self.instance
        if Coverband.configuration.collector == 'trace'
          Thread.current[:coverband_instance] ||= Coverband::Collectors::Trace.new
        elsif Coverband.configuration.collector == 'coverage'
          Thread.current[:coverband_instance] ||= Coverband::Collectors::Coverage.new
        else
          raise 'select valid collector [trace, coverage]'
        end
      end

      def start
        @enabled = true
        record_coverage
      end

      def stop
        @enabled = false
        stop_coverage
      end

      def sample
        configure_sampling
        record_coverage
        result = yield
        report_coverage
        result
      end

      def save
        @enabled = true
        report_coverage
        @enabled = false
      end

      def reset_instance
        @project_directory = File.expand_path(Coverband.configuration.root)
        @enabled = false
        @file_line_usage = {}
        @ignored_files = Set.new
        @ignore_patterns = Coverband.configuration.ignore + ['internal:prelude', 'schema.rb']
        @reporting_frequency = Coverband.configuration.reporting_frequency
        @store = Coverband.configuration.store
        @store = Coverband::Adapters::MemoryCacheStore.new(@store) if Coverband.configuration.memory_caching
        @verbose  = Coverband.configuration.verbose
        @logger   = Coverband.configuration.logger
        @current_thread = Thread.current
        Thread.current[:coverband_instance] = nil
        self
      end

      def configure_sampling
        if @startup_delay != 0 || (rand * 100.0) > @sample_percentage
          @startup_delay -= 1 if @startup_delay > 0
          @enabled = false
        else
          @enabled = true
        end
      end

      def record_coverage
        raise 'abstract'
      end

      def stop_coverage
        raise 'abstract'
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
          @logger.info "file: #{file} => #{lines.sort_by { |_key, value| value }}"
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
