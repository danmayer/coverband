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

      private

      attr_accessor :path

      def save_coverage(report)
        File.open(path, 'w') { |f| f.write(report.to_json) }
      end

      def get_report
        if File.exist?(path)
          JSON.parse(File.read(path))
        else
          {}
        end
      end
    end
  end
end
