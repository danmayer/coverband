# frozen_string_literal: true

module Coverband
  module Adapters
    ###
    # FilesStore store a merged coverage file to local disk
    # Generally this is for testing and development
    # Not recommended for production deployment
    ###
    class FileStore < Base
      def initialize(path, _opts = {})
        super()
        @path = path

        config_dir = File.dirname(@path)
        Dir.mkdir config_dir unless File.exist?(config_dir)
      end

      def clear!
        File.delete(path) if File.exist?(path)
      end

      def size
        File.size?(path).to_i
      end

      def migrate!
        raise NotImplementedError, "FileStore doesn't support migrations"
      end

      def coverage(_local_type = nil)
        if File.exist?(path)
          JSON.parse(File.read(path))
        else
          {}
        end
      end

      def save_report(report)
        data = report.dup
        data = merge_reports(data, coverage)
        File.open(path, 'w') { |f| f.write(data.to_json) }
      end

      private

      attr_accessor :path
    end
  end
end
