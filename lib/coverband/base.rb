require 'singleton'
require 'set'

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
      result = yield
      report_coverage
      result
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
      @disable_on_failure_for = Coverband.configuration.disable_on_failure_for
      @tracer_set = false
      @file_line_usage = {}
      @ignored_files = Set.new
      @startup_delay = Coverband.configuration.startup_delay
      @ignore_patterns = Coverband.configuration.ignore + ['internal:prelude', 'schema.rb'] 
      @ignore_patterns += ['gems'] unless Coverband.configuration.include_gems
      @sample_percentage = Coverband.configuration.percentage
      @store = Coverband.configuration.store
      @store = Coverband::Adapters::MemoryCacheStore.new(@store, max_caching: Coverband.configuration.max_caching) if Coverband.configuration.memory_caching
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
      if @enabled && !failed_recently?
        set_tracer
      else
        unset_tracer
      end
      @stats.increment "coverband.request.recorded.#{@enabled}" if @stats
    rescue RuntimeError => err
      failed!
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

      if failed_recently?
        @logger.info "coverage reporting sanding-by because of recent failure" if @verbose
        return
      end

      if @verbose
        @logger.info "coverband file usage: #{file_usage.inspect}"
        if @verbose=="debug"
          output_file_line_usage
        end
      end

      if @store
        if @stats
          @before_time = Time.now
          @stats.count "coverband.files.recorded_files", @file_line_usage.length
        end
        @store.save_report(@file_line_usage)
        if @stats
          @time_spent = Time.now - @before_time
          @stats.timing "coverband.files.recorded_time", @time_spent
        end
        @file_line_usage.clear
      elsif @verbose
        @logger.info "coverage report: "
        @logger.info @file_line_usage.inspect
      end
    rescue RuntimeError => err
      failed!
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

    def file_usage
      hash = {}
      @file_line_usage.each do |file, lines|
        hash[file] = lines.values.inject(0, :+)
      end
      hash.sort_by {|_key, value| value}
    end

    def add_file(file, line)
      @file_line_usage[file] = Hash.new(0) unless @file_line_usage.include?(file)
      @file_line_usage[file][line] += 1
    end

    def create_trace_point
      TracePoint.new(*Coverband.configuration.trace_point_events) do |tp|
        if Thread.current == @current_thread
          file = tp.path
          if !@ignored_files.include?(file)
            if track_file?(file)
              add_file(file, tp.lineno)
            else
              @ignored_files << file
            end
          end
        end
      end
    end

    def initialize
      reset_instance
    end

  end
end
