# frozen_string_literal: true

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
        unset_tracer
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
        @disable_on_failure_for = Coverband.configuration.disable_on_failure_for
        @file_line_usage = {}
        @ignored_files = Set.new
        @startup_delay = Coverband.configuration.startup_delay
        @ignore_patterns = Coverband.configuration.ignore + ['internal:prelude', 'schema.rb']
        @ignore_patterns += ['gems'] unless Coverband.configuration.include_gems
        @sample_percentage = Coverband.configuration.percentage
        @store = Coverband.configuration.store
        @store = Coverband::Adapters::MemoryCacheStore.new(@store) if Coverband.configuration.memory_caching
        @stats    = Coverband.configuration.stats
        @verbose  = Coverband.configuration.verbose
        @logger   = Coverband.configuration.logger
        @current_thread = Thread.current
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
        if @enabled && !failed_recently?
          set_tracer
        else
          unset_tracer
        end
        @stats.increment "coverband.request.recorded.#{@enabled}" if @stats
      rescue RuntimeError => err
        failed!
        if @verbose
          @logger.info 'error stating recording coverage'
          @logger.info "error: #{err.inspect} #{err.message}"
        end
      end

      def report_coverage
        raise 'abstract'
      end

      protected

      def track_file?(file)
        @ignore_patterns.none? { |pattern| file.include?(pattern) } && file.start_with?(@project_directory)
      end

      def set_tracer
        raise 'abstract'
      end

      def unset_tracer
        raise 'abstract'
      end

      def output_file_line_usage
        @logger.info 'coverband debug coverband file:line usage:'
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

      def failed_recently?
        return false unless @disable_on_failure_for && failed_at
        failed_at + @disable_on_failure_for > Time.now
      end

      def initialize
        reset_instance
      end
    end
  end
end
