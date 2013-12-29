module Coverband
  class Base

    def initialize(options = {})
      @project_directory = File.expand_path(Coverband.configuration.root)
      @enabled = false
      @tracer_set = false
      @files = {}
      @ignore_patterns = Coverband.configuration.ignore
      @sample_percentage = Coverband.configuration.percentage
      @reporter = Coverband::RedisStore.new(Coverband.configuration.redis)
      @verbose = Coverband.configuration.verbose
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
      if (rand * 100.0) > @sample_percentage
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
      if file.match(@project_directory) && !@ignore_patterns.any?{|pattern| file.match(/#{pattern}/) } 
        if @files.include?(file)
          @files[file] << line
          @files[file].uniq!
        else
          @files[file] = [line]
        end
      end
    end
    
    def report_coverage
      unless @enabled
        puts "coverage disabled" if @verbose
        return
      end

      unset_tracer

      if @reporter
        if @reporter.class.name.match(/redis/i)
          @reporter.store_report(@files)
          @files = {}
        end
      elsif @verbose
        puts "coverage report: "
        puts @files.inspect
      end
    rescue RuntimeError => err
      if @verbose
        puts "coverage missing"
        puts "error: #{err.inspect} #{err.message}"
      end
    end
  end
end
