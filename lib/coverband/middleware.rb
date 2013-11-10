module Coverband
  class Middleware

    def initialize(app, settings={})
      @app = app
      root = settings[:root] || './'
      @project_directory = File.expand_path(root)
      @enabled = true
      @function_set = false
      @files = {}

      @ignore_patterns = settings[:ignore] || []
      @sample_percentage = settings[:percentage] || 100.0
      @reporter = settings[:reporter]
    end

    def call(env)
      configure_sampling
      record_coverage
      results = @app.call(env)
      report_coverage
      results
    end

    private

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
          if @reporter
            if @reporter.is_a?(Redis)
              #"/Users/danmayer/projects/cover_band_server/app.rb"=>[54, 55]
              old_files = @files.dup
              @files = {}
              old_files.each_pair do |key, values|
                @reporter.sadd "coverband", key.gsub('/','.')
                @reporter.sadd "coverband#{key.gsub('/','.')}", values
              end
            end
          else
            puts "coverage report: "
            puts @files.inspect
          end
        else
          puts "coverage disabled" if @reporter
        end
      rescue RuntimeError => err
        if @reporter
          puts "coverage missing"
          puts "error: #{err.inspect} #{err.message}"
        end
      end
    end
    
  end
end
