# frozen_string_literal: true

module Coverband
  module Collectors
    class Coverage < Base
      def array_diff(latest, original)
        latest.map.with_index { |v, i| v ? v - original[i] : nil }
      end

      def report_coverage
        unless @enabled
          @logger.info 'coverage disabled' if @verbose
          return
        end

        if failed_recently?
          @logger.info 'coverage reporting standing-by because of recent failure' if @verbose
          return
        end

        current_results = ::Coverage.peek_result
        # if current_results['/Users/danmayer/projects/rails_benchmark/app/controllers/posts_controller.rb']
        #   puts "total"
        #   puts current_results['/Users/danmayer/projects/rails_benchmark/app/controllers/posts_controller.rb'].inspect
        # end
        # if @previous_results
        #   new_results = {}
        #   current_results.each_pair do |file,line_counts|
        #     new_results[file] = array_diff(line_counts, @previous_results[file])
        #   end
        # else
        #   new_results = current_results
        # end
        #
        # if @previous_results && @previous_results['/Users/danmayer/projects/rails_benchmark/app/controllers/posts_controller.rb']
        #   puts "prev"
        #   puts @previous_results['/Users/danmayer/projects/rails_benchmark/app/controllers/posts_controller.rb'].inspect
        # end
        #
        # if current_results['/Users/danmayer/projects/rails_benchmark/app/controllers/posts_controller.rb']
        #   puts "new"
        #   puts new_results['/Users/danmayer/projects/rails_benchmark/app/controllers/posts_controller.rb'].inspect
        # end

        # todo move back to new_results
        current_results.each_pair do |file, line_counts|
          next if @ignored_files.include?(file)
          next unless track_file?(file)
          add_file(file, line_counts)
        end
        # this concept fails across threads
        # as the  coverage is shared across all threads
        # but the @previous_results is thread local
        # how to share it acrss threads or pull from RedisStore
        # regardlesss we can likely make this as slow as we need when we change coverage
        # to report every X seconds and on exit
        @previous_results = current_results

        if @verbose
          @logger.info "coverband file usage: #{file_usage.inspect}"
          output_file_line_usage if @verbose == 'debug'
        end

        if @store
          if @stats
            @before_time = Time.now
            @stats.count 'coverband.files.recorded_files', @file_line_usage.length
          end
          # puts "coverage report"
          # puts @file_line_usage['/Users/danmayer/projects/rails_benchmark/app/controllers/posts_controller.rb'].inspect
          @store.save_report(@file_line_usage)
          if @stats
            @time_spent = Time.now - @before_time
            @stats.timing 'coverband.files.recorded_time', @time_spent
          end
          @file_line_usage.clear
        elsif @verbose
          @logger.info 'coverage report: '
          @logger.info @file_line_usage.inspect
        end
      rescue RuntimeError => err
        failed!
        if @verbose
          @logger.info 'coverage missing'
          @logger.info "error: #{err.inspect} #{err.message}"
        end
      end

      protected

      def set_tracer
        # no op
      end

      def unset_tracer
        # no op
      end

      private

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
        unless defined?(Coverage)
          puts 'loading coverage'
          require 'coverage'
          Coverage.start
        end
        @previous_results = nil
        reset_instance
      end
    end
  end
end
