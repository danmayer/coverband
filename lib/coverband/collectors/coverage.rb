# frozen_string_literal: true
require 'singleton'

module Coverband
  module Collectors
    ###
    # TODO: look at alternatives to semaphore
    # StandardError seems like be better option
    # coverband previously had RuntimeError here
    # but runtime error can let a large number of error crash this method
    # and this method is currently in a ensure block in middleware and threads
    ###
    class Coverage
      include Singleton
      extend Forwardable

      class Delta
        attr_reader :current_coverage

        def initialize(current_coverage)
          @current_coverage = current_coverage
        end

        def self.new_coverage(current_coverage)
          new(current_coverage).new_coverage
        end

        def new_coverage
          new_results = generate.dup
          @@previous_results = current_coverage
          new_results
        end

        def self.reset
          @@previous_results = nil
        end

        private

        def generate
          if @@previous_results
            current_coverage.each_with_object({}) do |(file, line_counts), new_results|
              if @@previous_results[file]
                new_results[file] = array_diff(line_counts, @@previous_results[file])
              else
                new_results[file] = line_counts
              end
            end
          else
            current_coverage
          end
        end

        def array_diff(latest, original)
          latest.map.with_index do |v, i|
            if (v && original[i])
              [0, v - original[i]].max
            else
              nil
            end
          end
        end
      end

      def reset_instance
        @project_directory = File.expand_path(Coverband.configuration.root)
        @file_line_usage = {}
        @ignore_patterns = Coverband.configuration.ignore + ['internal:prelude', 'schema.rb']
        @reporting_frequency = Coverband.configuration.reporting_frequency
        @store = Coverband.configuration.store
        @verbose  = Coverband.configuration.verbose
        @logger   = Coverband.configuration.logger
        @test_env = Coverband.configuration.test_env
        @track_gems = Coverband.configuration.track_gems
        Delta.reset
        Thread.current[:coverband_instance] = nil
        self
      end

      def runtime!
        @store.type = nil
      end

      def eager_loading!
        @store.type = Coverband::EAGER_TYPE
      end

      def report_coverage(force_report = false)
        return if !ready_to_report? && !force_report
        raise 'no Coverband store set' unless @store
        original_previous_set = previous_results
        new_results = get_new_coverage_results
        add_filtered_files(new_results)

        ###
        # Hack to prevent processes and threads from reporting first Coverage hit
        # when we are in runtime collection mode, which do not have a cache of previous
        # coverage to remove the initial stdlib Coverage loading data
        ###
        if ((original_previous_set.nil? && @store.type == Coverband::EAGER_TYPE) ||
           (original_previous_set && @store.type != Coverband::EAGER_TYPE))
          @store.save_report(files_with_line_usage)
        end
        @file_line_usage.clear
      rescue StandardError => err
        if @verbose
          @logger&.error 'coverage failed to store'
          @logger&.error "error: #{err.inspect} #{err.message}"
          @logger&.error err.backtrace
        end
        raise err if @test_env
      end

      protected

      def delta
        @delta ||= Delta.new
      end

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

      def add_filtered_files(new_results)
        new_results.each_pair do |file, line_counts|
          next unless track_file?(file)
          add_file(file, line_counts)
        end
      end

      def ready_to_report?
        (rand * 100.0) >= (100.0 - @reporting_frequency)
      end

      def get_new_coverage_results
        @semaphore.synchronize { Delta.new_coverage(::Coverage.peek_result.dup) }
      end

      def files_with_line_usage
        @file_line_usage.select do |_file_name, coverage|
          coverage.any? { |value| value&.nonzero? }
        end
      end

      def array_diff(latest, original)
        latest.map.with_index do |v, i|
          if (v && original[i])
            [0, v - original[i]].max
          else
            nil
          end
        end
      end

      def add_file(file, line_counts)
        @file_line_usage[file] = line_counts
      end

      def initialize
        if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3.0')
          raise NotImplementedError, 'not supported until Ruby 2.3.0 and later'
        end
        require 'coverage'
        if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.5.0')
          ::Coverage.start unless ::Coverage.running?
        else
          ::Coverage.start
        end
        if Coverband.configuration.safe_reload_files
          Coverband.configuration.safe_reload_files.each do |safe_file|
            load safe_file
          end
        end
        @semaphore = Mutex.new
        @@previous_results = nil
        reset_instance
      end
    end
  end
end
