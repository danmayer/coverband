# frozen_string_literal: true

module Coverband
  module Collectors
    ###
    # TODO: likely flatten and remove the collectors and base
    # TODO: nothing currently handles relative path
    # ensuring it is the same across deployments etc
    # could be handled during collection, storing, or processing for reporting
    # TODO: look at alternatives to semaphore
    # StandardError seems line be better option
    # coverband previously had RuntimeError here
    # but runtime error can let a large number of error crash this method
    # and this method is currently in a ensure block in middleware and threads
    ###
    class Coverage < Base
      def report_coverage
        return unless ready_to_report?
        unless @store
          @logger.debug 'no store set, no-op'
          return
        end
        new_results = get_new_coverage_results
        add_filtered_files(new_results)
        @store.save_report(files_with_line_usage)
        @file_line_usage.clear
      rescue StandardError => err
        if @verbose
          @logger.error 'coverage failed to store'
          @logger.error "error: #{err.inspect} #{err.message}"
          @logger.error err.backtrace
        end
      end

      private

      def add_filtered_files(new_results)
        new_results.each_pair do |file, line_counts|
          next if @ignored_files.include?(file)
          next unless track_file?(file)
          add_file(file, line_counts)
        end
      end

      def ready_to_report?
        (rand * 100.0) >= (100.0 - @reporting_frequency)
      end

      def get_new_coverage_results
        coverage_results = nil
        @semaphore.synchronize { coverage_results = new_coverage(::Coverage.peek_result.dup) }
        coverage_results
      end

      def files_with_line_usage
        @file_line_usage.select do |_file_name, coverage|
          coverage.any? { |value| value && value.nonzero? }
        end
      end

      def array_diff(latest, original)
        latest.map.with_index { |v, i| (v && original[i]) ? v - original[i] : nil }
      end

      def previous_results
        @@previous_results
      end

      def add_previous_results(val)
        @@previous_results = val
      end

      def new_coverage(current_coverage)
        if previous_results
          new_results = {}
          current_coverage.each_pair do |file, line_counts|
            if previous_results[file]
              new_results[file] = array_diff(line_counts, previous_results[file])
            else
              new_results[file] = line_counts
            end
          end
        else
          new_results = current_coverage
        end

        add_previous_results(current_coverage)
        new_results.dup
      end

      def add_file(file, line_counts)
        @file_line_usage[file] = line_counts
      end

      def initialize
        if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3.0')
          raise NotImplementedError, 'not supported until Ruby 2.3.0 and later'
        end
        unless defined?(::Coverage)
          # puts 'loading coverage'
          require 'coverage'
        end
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
