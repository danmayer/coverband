module Coverband
  class Base

    def initialize(options = {})
      @project_directory = File.expand_path(Coverband.configuration.root)
      @enabled = false
      @function_set = false
      @files = {}
      @ignore_patterns = Coverband.configuration.ignore
      @sample_percentage = Coverband.configuration.percentage
      @reporter = Coverband.configuration.redis
      @verbose = Coverband.configuration.verbose
    end

    def start
      @enabled = true
      record_coverage
    end
    
    def stop
      @enabled = false
      if @function_set
        set_trace_func(nil)
        @function_set = false
      end
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
        unless @function_set
          set_trace_func proc { |event, file, line, id, binding, classname|
            add_file(file, line)
          }
          @function_set = true
        end
      else
        if @function_set
          set_trace_func(nil)
          @function_set = false
        end
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
      begin
        if @enabled
          if @function_set
            set_trace_func(nil)
            @function_set = false
          end
          if @reporter
            if @reporter.class.name.match(/redis/i)
              #"/Users/danmayer/projects/cover_band_server/app.rb"=>[54, 55]
              @files.each_pair do |key, values|
                @reporter.sadd "coverband", key
                #clean this up but redis gem v2.x doesn't allow sadd with a collection, this is slow
                if @reporter.inspect.match(/v2/)
                  values.each do |value|
                    @reporter.sadd "coverband.#{key}", value
                  end
                else
                  @reporter.sadd "coverband.#{key}", values
                end
              end
              @files = {}
            end
          else
            puts "coverage report: " if @verbose
            puts @files.inspect if @verbose
          end
        else
          puts "coverage disabled" if @verbose
        end
      rescue RuntimeError => err
        if @verbose
          puts "coverage missing" 
          puts "error: #{err.inspect} #{err.message}"
        end
      end
    end
    
  end
end
