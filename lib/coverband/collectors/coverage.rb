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
        @verbose = Coverband.configuration.verbose
        @logger = Coverband.configuration.logger
        @test_env = Coverband.configuration.test_env
        Delta.reset
        self
      end

      def runtime!
        @store.type = Coverband::RUNTIME_TYPE
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
        @logger&.error 'coverage failed to store'
        @logger&.error "Coverband Error: #{e.inspect} #{e.message}"
        e.backtrace.each { |line| @logger&.error line } if @verbose
        raise e if @test_env
      end

      private

      def filtered_files(new_results)
        new_results.select! { |_file, coverage| coverage.any? { |value| value&.nonzero? } }
        new_results
      end

      def initialize
        @semaphore = Mutex.new
        raise NotImplementedError, 'Coverage needs Ruby > 2.3.0' if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3.0')

        require 'coverage'
        if defined?(SimpleCov) && defined?(Rails) && defined?(Rails.env) && Rails.env.test?
          puts "Coverband: detected SimpleCov in test Env, allowing it to start Coverage"
          puts "Coverband: to ensure no error logs or missing Coverage call `SimpleCov.start` prior to requiring Coverband"
        else
          if Coverage.ruby_version_greater_than_or_equal_to?('2.6.0')
            ::Coverage.start(oneshot_lines: Coverband.configuration.use_oneshot_lines_coverage) unless ::Coverage.running?
          elsif Coverage.ruby_version_greater_than_or_equal_to?('2.5.0')
            ::Coverage.start unless ::Coverage.running?
          else
            ::Coverage.start
          end
        end
        reset_instance
      end
    end
  end
end
