require "coverband/version"

module Coverband
  class Middleware

    def initialize(app, settings={})
      @app = app
      root = settings[:root] || './'
      @project_directory = File.expand_path(root+'../')
      @enabled = true
      @sample_percentage = 100.0
      @function_set = false
      @files = {}
      puts @project_directory
      puts "*"*40
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
      if rand > 1.0
        @enabled = false
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
      unless !file.match(@project_directory) 
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
          puts "coverage report: "
          puts @files.inspect
        else
          puts "coverage disabled"
        end
      rescue RuntimeError
        puts "coverage missing"
      end
    end
    
  end
end
