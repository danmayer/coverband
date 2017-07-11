module Coverband
  class Baseline

    def self.record
      require 'coverage'
      Coverage.start
      #binding.pry
      yield

      project_directory = File.expand_path(Coverband.configuration.root)
      results = Coverage.result
      results = results.reject { |key, val| !key.match(project_directory) || Coverband.configuration.ignore.any? { |pattern| key.match(/#{pattern}/) } }

      Coverband.configuration.store.save_report(convert_coverage_format(results))
    end

    def self.parse_baseline(back_compat = nil)
      Coverband.configuration.store.coverage
    end

    def self.exclude_files(files)
      Coverband.configuration.ignore.each do |ignore|
        path = Coverband.configuration.root + "/#{ignore}"
        excludes = File.directory?(path) ? Dir.glob("#{path}/**/*") : [path]
        files -= excludes
      end
      files
    end

    private

    def self.convert_coverage_format(results)
      file_map = {}
      results.each_pair do |file, data|
        lines_map = {}
        data.each_with_index do |hits, index|
          lines_map[(index+1)] = hits unless hits.nil?
        end
        file_map[file] = lines_map
      end
      file_map
    end

  end
end
