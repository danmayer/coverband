require 'singleton'

module Coverband
  class Base

    def self.instance
      Thread.current[:coverband_instance] ||= Coverband::Base.new
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
      yield
      report_coverage
    end

    def save
      @enabled = true
      report_coverage
      @enabled = false
    end

    def extended?
      false
    end

    def reset_instance
      @project_directory = File.expand_path(Coverband.configuration.root)
      @enabled = false
      @tracer_set = false
      @file_usage = Hash.new(0)
      @file_line_usage = {}
      @startup_delay = Coverband.configuration.startup_delay
      @ignore_patterns = Coverband.configuration.ignore + ["internal:prelude"]
      @ignore_patterns += ['gems'] unless Coverband.configuration.include_gems
      @sample_percentage = Coverband.configuration.percentage
      if Coverband.configuration.redis
        @reporter = Coverband::RedisStore.new(Coverband.configuration.redis)
        @reporter = Coverband::MemoryCacheStore.new(@reporter) if Coverband.configuration.memory_caching
      end
      @stats    = Coverband.configuration.stats
      @verbose  = Coverband.configuration.verbose
      @logger   = Coverband.configuration.logger
      @current_thread = Thread.current
      @trace = create_trace_point
      self
    end

    def configure_sampling
      if @startup_delay!=0 || (rand * 100.0) > @sample_percentage
        @startup_delay -= 1 if @startup_delay > 0
        @enabled = false
      else
        @enabled = true
      end
    end

    def record_coverage
      if @enabled
        set_tracer
      else
        unset_tracer
      end
      @stats.increment "coverband.request.recorded.#{@enabled}" if @stats
    rescue RuntimeError => err
      if @verbose
        @logger.info "error stating recording coverage"
        @logger.info "error: #{err.inspect} #{err.message}"
      end
    end

    def report_coverage
      unless @enabled
        @logger.info "coverage disabled" if @verbose
        return
      end

      unset_tracer

      @file_line_usage.reject!{|file, _lines| !track_file?(file) }

      if @verbose
        @logger.info "coverband file usage: #{@file_usage.sort_by {|_key, value| value}.inspect}"
        if @verbose=="debug"
          output_file_line_usage
        end
      end

      if @reporter
        if @stats
          @before_time = Time.now
          @stats.count "coverband.files.recorded_files", @file_line_usage.length
        end
        @reporter.store_report(@file_line_usage)
        if @stats
          @time_spent = Time.now - @before_time
          @stats.timing "coverband.files.recorded_time", @time_spent
        end
        @file_line_usage.clear
        if @verbose
          @file_usage.clear
        end
      elsif @verbose
        @logger.info "coverage report: "
        @logger.info @file_line_usage.inspect
      end
    rescue RuntimeError => err
      if @verbose
        @logger.info "coverage missing"
        @logger.info "error: #{err.inspect} #{err.message}"
      end
    end

    protected

    def track_file? file
      !@ignore_patterns.any?{ |pattern| file.include?(pattern) } && file.start_with?(@project_directory)
    end


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

    def output_file_line_usage
      @logger.info "coverband debug coverband file:line usage:"
      @file_line_usage.sort_by {|_key, value| value.length}.each do |pair|
                                                             file = pair.first
                                                             lines = pair.last
                                                             @logger.info "file: #{file} => #{lines.sort_by {|_key, value| value}}"
                                                           end
    end

    private

    def create_trace_point
      TracePoint.new(*Coverband.configuration.trace_point_events) do |tp|
        if Thread.current == @current_thread
          file = tp.path
          line = tp.lineno
          if @verbose
            @file_usage[file] += 1
          end
          @file_line_usage[file] = Hash.new(0) unless @file_line_usage.include?(file)
          @file_line_usage[file][line] += 1
        end
      end
    end

    def initialize
      reset_instance
    end

  end
end
