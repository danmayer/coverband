# frozen_string_literal: true

module Coverband
  class BackgroundForMultiProcess
    include Singleton

    def self.start
      instance.start
    end

    def self.stop
      instance.stop
    end

    def initialize
      if !Coverband.configuration.store.is_a?(Coverband::Adapters::FileStore)
        raise 'Coverband::BackgroundForMultiProcess only supports children processes using the FileStore adapter'
      end

      @semaphore = Mutex.new
      @thread = nil
      @pid = nil

      @store = Coverband.configuration.store_for_multi_process_background
      @filepath_pattern = "#{
        Coverband.configuration.filepath_pattern_for_multi_process ||
          File.join(Dir.mktmpdir("coverband_#{Time.now.to_i}"), "coverage")
      }.*"
      @batch_size = Coverband.configuration.batch_size_for_multi_process || 1000
    end

    def stop
      return unless @thread

      @semaphore.synchronize do
        if @thread
          @thread.exit
          @thread = nil
        end
      end
    end

    def running?
      @thread&.alive?
    end

    def start
      return if running?
      return if !@pid.nil?

      @pid = Process.pid

      logger = Coverband.configuration.logger
      @semaphore.synchronize do
        return if running?

        logger.debug("Coverband: Starting background reporting") if Coverband.configuration.verbose
        sleep_seconds = Coverband.configuration.background_reporting_sleep_seconds.to_i
        @thread = Thread.new {
          Thread.current.name = "Coverband Background Reporter"

          loop do
            if @pid != Process.pid
              logger.debug("Coverband: New process detected, stopping background reporting")
              stop
              break
            end

            if Coverband.configuration.reporting_wiggle
              sleep_seconds = Coverband.configuration.background_reporting_sleep_seconds.to_i + rand(Coverband.configuration.reporting_wiggle.to_i)
            end
            # NOTE: Normally as processes first start we immediately report, this causes a redis spike on deploys
            # if deferred is set also sleep frst to spread load
            sleep(sleep_seconds.to_i) if Coverband.configuration.defer_eager_loading_data?
            process_files
            if Coverband.configuration.verbose
              logger.debug("Coverband: background reporting coverage (#{Coverband.configuration.store.type}). Sleeping #{sleep_seconds}s")
            end
            sleep(sleep_seconds.to_i) unless Coverband.configuration.defer_eager_loading_data?
          end
        }
      end
    rescue ThreadError
      stop
    end

    private

    def process_files
      files = Dir.glob(@filepath_pattern)
      return if files.empty?

      Coverband.configuration.logger.debug("Processing #{files.length} coverage files")

      files.each_slice(@batch_size) do |batch|
        coverage_report = {}

        batch.each do |file|
          begin
            report = JSON.parse(File.read(file))
            next if report.nil?
            merge_reports(coverage_report, report)
            File.delete(file)
          rescue JSON::ParserError => e
            Coverband.configuration.logger.error("Error parsing file #{file}: #{e.message}")
          rescue => e
            Coverband.configuration.logger.error("Error processing file #{file}: #{e.message}")
          end
        end

        results = convert_report_to_results(coverage_report)

        @store.save_report(results) unless results.empty?
      end
    end

    def merge_reports(first_report, second_report, options = {})
      Coverband::Adapters::Base.new.send(
        :merge_reports,
        first_report,
        second_report,
        {skip_expansion: true}
      )
    end

    def convert_report_to_results(coverage_report)
      coverage_report.each_with_object({}) do |(file, coverage), results|
        results[file] = coverage["data"]
      end
    end
  end
end
