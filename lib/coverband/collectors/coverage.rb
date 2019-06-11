# frozen_string_literal: true

require 'singleton'
require_relative 'delta'

module Coverband
  module Collectors
    ###
    # StandardError seems like be better option
    # coverband previously had RuntimeError here
    # but runtime error can let a large number of error crash this method
    # and this method is currently in a ensure block in middleware and threads
    ###
    class Coverage
      include Singleton

      def self.ruby_version_greater_than_or_equal_to?(version)
        Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(version)
      end

      def reset_instance
        @project_directory = File.expand_path(Coverband.configuration.root)
        @ignore_patterns = Coverband.configuration.ignore
        @store = Coverband.configuration.store
        @verbose  = Coverband.configuration.verbose
        @logger   = Coverband.configuration.logger
        @test_env = Coverband.configuration.test_env
        @track_gems = Coverband.configuration.track_gems
        Delta.reset
        self
      end

      def runtime!
        @store.type = nil
      end

      def eager_loading!
        @store.type = Coverband::EAGER_TYPE
      end

      def eager_loading
        old_coverage_type = @store.type
        eager_loading!
        yield
      ensure
        report_coverage
        @store.type = old_coverage_type
      end

      def report_coverage
        @semaphore.synchronize do
          raise 'no Coverband store set' unless @store

          files_with_line_usage = filtered_files(Delta.results)
          @store.save_report(files_with_line_usage)
        end
      rescue StandardError => e
        if @verbose
          @logger.error 'coverage failed to store'
          @logger.error "error: #{e.inspect} #{e.message}"
          e.backtrace.each { |line| @logger.error line }
        end
        raise e if @test_env
      end

      protected

      ###
      # Normally I would break this out into additional methods
      # and improve the readability but this is in a tight loop
      # on the critical performance path, and any refactoring I come up with
      # would slow down the performance.
      ###
      def track_file?(file)
        @ignore_patterns.none? do |pattern|
          file.include?(pattern)
        end && (file.start_with?(@project_directory) ||
                (@track_gems &&
                 Coverband.configuration.gem_paths.any? { |path| file.start_with?(path) }))
      end

      private

      def filtered_files(new_results)
        new_results.select! { |file, coverage| track_file?(file) && coverage.any? { |value| value&.nonzero? } }
        new_results
      end

      def initialize
        @semaphore = Mutex.new
        raise NotImplementedError, 'Coverage needs Ruby > 2.3.0' if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3.0')

        require 'coverage'
        if Coverage.ruby_version_greater_than_or_equal_to?('2.6.0')
          ::Coverage.start(oneshot_lines: Coverband.configuration.use_oneshot_lines_coverage) unless ::Coverage.running?
        elsif Coverage.ruby_version_greater_than_or_equal_to?('2.5.0')
          ::Coverage.start unless ::Coverage.running?
        else
          ::Coverage.start
        end
        reset_instance
      end
    end
  end
end
