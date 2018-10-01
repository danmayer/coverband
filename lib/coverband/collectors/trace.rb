# frozen_string_literal: true

module Coverband
  module Collectors
    ###
    # NOTE: While this still works it is slower than Coverage.
    # I recommend using the Coverage adapter.
    # As baseline is removed the Trace collector also doesn't have a good way
    # to collect initial code usage during app boot up.
    #
    # I am leaving Trace around as I believe there are some interesting use cases
    # also, it illustrates an alternative collector, and I have some others I would like to implement
    ###
    class Trace < Base
      def reset_instance
        super
        @tracer_set = false
        @trace_point_events = [:line]
        @trace = create_trace_point
        self
      end

      def record_coverage
        if @enabled && !failed_recently?
          set_tracer
        else
          unset_tracer
        end
      rescue RuntimeError => err
        failed!
        if @verbose
          @logger.error 'error stating recording coverage'
          @logger.error "error: #{err.inspect} #{err.message}"
          @logger.error err.backtrace
        end
      end

      def stop_coverage
        unset_tracer
      end

      def report_coverage_potentially_forked
        unless @enabled
          @logger.info 'coverage disabled' if @verbose
          return
        end

        unset_tracer

        if failed_recently?
          @logger.error 'coverage reporting standing-by because of recent failure' if @verbose
          return
        end

        if @verbose
          @logger.debug "coverband file usage: #{file_usage.inspect}"
          output_file_line_usage if @verbose == 'debug'
        end

        if @store
          @store.save_report(@file_line_usage)
          @file_line_usage.clear
        elsif @verbose
          @logger.info 'coverage report: '
          @logger.info @file_line_usage.inspect
        end
      rescue RuntimeError => err
        failed!
        if @verbose
          @logger.error 'coverage missing'
          @logger.error "error: #{err.inspect} #{err.message}"
          @logger.error err.backtrace
        end
      end

      protected

      def set_tracer
        unless @tracer_set
          @trace.enable
          @tracer_set = true
        end
      end

      def unset_tracer
        @trace.disable
        @tracer_set = false
      end

      private

      def add_file(file, line)
        @file_line_usage[file] = Hash.new(0) unless @file_line_usage.include?(file)
        @file_line_usage[file][line] += 1
      end

      def file_usage
        hash = {}
        @file_line_usage.each do |file, lines|
          hash[file] = lines.values.inject(0, :+)
        end
        hash.sort_by { |_key, value| value }
      end

      def create_trace_point
        TracePoint.new(*@trace_point_events) do |tp|
          if Thread.current == @current_thread
            file = tp.path

            unless @ignored_files.include?(file)
              if track_file?(file)
                add_file(file, tp.lineno)
              else
                @ignored_files << file
              end
            end
          end
        end
      end
    end
  end
end
