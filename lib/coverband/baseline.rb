module Coverband
  class Baseline
    #TODO baseline should be configurable to use default / same store

    def self.record
      require 'coverage'
      Coverage.start
      yield

      project_directory = File.expand_path(Coverband.configuration.root)
      results = Coverage.result
      results = results.reject { |key, val| !key.match(project_directory) || Coverband.configuration.ignore.any? { |pattern| key.match(/#{pattern}/) } }

      if Coverband.configuration.verbose
        Coverband.configuration.logger.info results.inspect
      end

      config_dir = File.dirname(Coverband.configuration.baseline_file)
      Dir.mkdir config_dir unless File.exist?(config_dir)
      Coverband::Adapters::FileStore.new(Coverband.configuration.baseline_file).save_report(results)
    end

    def self.parse_baseline(baseline_file = Coverband.configuration.baseline_file)
      Coverband::Adapters::FileStore.new(Coverband.configuration.baseline_file).coverage
    end

  end
end
