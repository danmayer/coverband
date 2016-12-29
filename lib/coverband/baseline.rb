module Coverband
  class Baseline

    def self.record
      require 'coverage'
      Coverage.start
      yield
      @project_directory = File.expand_path(Coverband.configuration.root)
      results = Coverage.result
      results = results.reject { |key, val| !key.match(@project_directory) || Coverband.configuration.ignore.any? { |pattern| key.match(/#{pattern}/) } }

      if Coverband.configuration.verbose
        Coverband.configuration.logger.info results.inspect
      end

      config_dir = File.dirname(Coverband.configuration.baseline_file)
      Dir.mkdir config_dir unless File.exist?(config_dir)
      File.open(Coverband.configuration.baseline_file, 'w') { |f| f.write(results.to_json) }
    end

    def self.parse_baseline(baseline_file = Coverband.configuration.baseline_file)
      baseline = if File.exist?(baseline_file)
                   JSON.parse(File.read(baseline_file))
                 else
                   {}
                 end
    end

  end
end
