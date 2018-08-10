# frozen_string_literal: true

module Coverband
  module Collectors
    class Coverage < Base
      def record_coverage
        # noop
      end

      def stop_coverage
        # noop
      end

      def report_coverage
        unless @enabled
          @logger.info 'coverage disabled' if @verbose
          return
        end

        if failed_recently?
          @logger.error 'coverage reporting standing-by because of recent failure' if @verbose
          return
        end

        new_results = nil
        @semaphore.synchronize { new_results = new_coverage(::Coverage.peek_result.dup) }
        new_results.each_pair do |file, line_counts|
          next if @ignored_files.include?(file)
          next unless track_file?(file)
          add_file(file, line_counts)
        end

        if @verbose
          @logger.debug "coverband file usage: #{file_usage.inspect}"
          output_file_line_usage if @verbose == 'debug'
        end

        if @store
          @store.save_report(@file_line_usage)
          @file_line_usage.clear
        elsif @verbose
          @logger.debug 'coverage report: '
          @logger.debug @file_line_usage.inspect
        end
      # StandardError might be better option
      # coverband previously had RuntimeError here
      # but runtime error can let a large number of error crash this method
      # and this method is currently in a ensure block in middleware
      rescue StandardError => err
        failed!
        if @verbose
          @logger.error 'coverage missing'
          @logger.error "error: #{err.inspect} #{err.message}"
          @logger.error err.backtrace.join("\n")
        end
      end

      private

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

      # TODO this seems like a dumb conversion for the already good coverage format
      # coverage is 0 based other implementation matches line number
      def add_file(file, line_counts)
        @file_line_usage[file] = Hash.new(0) unless @file_line_usage.include?(file)
        line_counts.each_with_index do |line_count, index|
          @file_line_usage[file][(index + 1)] = line_count if line_count
        end
      end

      def file_usage
        hash = {}
        @file_line_usage.each do |file, lines|
          hash[file] = lines.values.compact.inject(0, :+)
        end
        hash.sort_by { |_key, value| value }
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
