# frozen_string_literal: true

module Coverband
  module Adapters
    ###
    # FileStore store a merged coverage file to local disk
    #
    # Notes: Concurrency
    # * threadsafe as the caller to save_report uses @semaphore.synchronize
    # * file access process safe as each file written per process PID
    #
    # Usage:
    # config.store = Coverband::Adapters::FileStore.new('log/coverage.log')
    #
    # View Reports:
    # Using this assumes you are syncing the coverage files
    # to some shared storage that is accessible outside of the production server
    # download files to a system where you want to view the reports..
    # When viewing coverage from the filestore adapter it merges all coverage
    # files matching the path pattern, in this case `log/coverage.log.*`
    #
    # run: `bundle exec rake coverband:coverage_server`
    # open http://localhost:9022/
    #
    # one could also build a report via code, the output is suitable to feed into SimpleCov
    #
    # ```
    # coverband.configuration.store.merge_mode = true
    # coverband.configuration.store.coverage
    # ```
    ###
    class FileStore < Base
      attr_accessor :merge_mode
      def initialize(path, _opts = {})
        super()
        @path = "#{path}.#{::Process.pid}"
        @merge_mode = false

        config_dir = File.dirname(@path)
        Dir.mkdir config_dir unless File.exist?(config_dir)
      end

      def clear!
        File.delete(path) if File.exist?(path)
      end

      def size
        File.size?(path).to_i
      end

      def coverage(_local_type = nil, opts = {})
        if merge_mode
          data = {}
          Dir[path.sub(/\.\d+/, ".*")].each do |path|
            data = merge_reports(data, JSON.parse(File.read(path)), skip_expansion: true)
          end
          data
        elsif File.exist?(path)
          JSON.parse(File.read(path))
        else
          {}
        end
      rescue Errno::ENOENT
        {}
      end

      def save_report(report)
        data = report.dup
        data = merge_reports(data, coverage)
        File.write(path, JSON.dump(data))
      end

      def raw_store
        raise NotImplementedError, "FileStore doesn't support raw_store"
      end

      private

      attr_accessor :path
    end
  end
end
