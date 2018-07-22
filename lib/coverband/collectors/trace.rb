# frozen_string_literal: true

module Coverband
  module Collectors
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
          @logger.info 'error stating recording coverage'
          @logger.info "error: #{err.inspect} #{err.message}"
        end
      end

      def stop_coverage
        unset_tracer
      end

      def report_coverage
        unless @enabled
          @logger.info 'coverage disabled' if @verbose
          return
        end

        unset_tracer

        if failed_recently?
          @logger.info 'coverage reporting standing-by because of recent failure' if @verbose
          return
        end

        if @verbose
          @logger.info "coverband file usage: #{file_usage.inspect}"
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
          @logger.info 'coverage missing'
          @logger.info "error: #{err.inspect} #{err.message}"
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
