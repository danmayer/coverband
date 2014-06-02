module Coverband
  class Base

    def initialize(options = {})
      @project_directory = File.expand_path(Coverband.configuration.root)
      @enabled = false
      @tracer_set = false
      @files = {}
      @file_usage = Hash.new(0)
      @file_line_usage = {}
      @startup_delay = Coverband.configuration.startup_delay
      @ignore_patterns = Coverband.configuration.ignore
      @sample_percentage = Coverband.configuration.percentage
      @reporter = Coverband::RedisStore.new(Coverband.configuration.redis) if Coverband.configuration.redis
      @stats    = Coverband.configuration.stats
      @verbose  = Coverband.configuration.verbose
      @logger   = Coverband.configuration.logger || Logger.new(STDOUT)
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

    protected

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

    def set_tracer
      unless @tracer_set
        set_trace_func proc { |event, file, line, id, binding, classname|
          add_file(file, line)
        }
        @tracer_set = true
      end
    end

    def unset_tracer
      if @tracer_set
        set_trace_func(nil)
        @tracer_set = false
      end
    end
    
    def add_file(file, line)
      if !file.match(/(\/gems\/|internal\:prelude)/) && file.match(@project_directory) && !@ignore_patterns.any?{|pattern| file.match(/#{pattern}/) } 
        if @verbose
          @file_usage[file] += 1
          @file_line_usage[file] = Hash.new(0) unless @file_line_usage.include?(file)
          @file_line_usage[file][line] += 1
        end
        if @files.include?(file)
          @files[file] << line unless @files.include?(line)
        else
          @files[file] = [line]
        end
      end
    end

    def output_file_line_usage
      @logger.info "coverband debug coverband file:line usage:"
      @file_line_usage.sort_by {|_key, value| value.length}.each do |pair|
                                                             file = pair.first
                                                             lines = pair.last
                                                             @logger.info "file: #{file} => #{lines.sort_by {|_key, value| value}}"
                                                           end
    end
    
    def report_coverage
      unless @enabled
        @logger.info "coverage disabled" if @verbose
        return
      end

      unset_tracer

      if @verbose
        @logger.info "coverband file usage: #{@file_usage.sort_by {|_key, value| value}.inspect}"
        if @verbose=="debug"
          output_file_line_usage
        end
      end

      if @reporter
        if @reporter.class.name.match(/redis/i)
          before_time = Time.now
          @stats.increment "coverband.files.recorded_files", @files.length if @stats
          @reporter.store_report(@files)
          time_spent = Time.now - before_time
          @stats.timing "coverband.files.recorded_time", time_spent if @stats
          @files = {}
          @file_usage = Hash.new(0)
          @file_line_usage = {}
        end
      elsif @verbose
        @logger.info "coverage report: "
        @logger.info @files.inspect
      end
    rescue RuntimeError => err
      if @verbose
        @logger.info "coverage missing"
        @logger.info "error: #{err.inspect} #{err.message}"
      end
    end
  end
end
