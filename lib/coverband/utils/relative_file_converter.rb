# frozen_string_literal: true

module Coverband
  module Utils
    class RelativeFileConverter
      def self.instance
        @instance ||= new(Coverband.configuration.all_root_paths)
      end

      def self.reset
        @instance = nil
      end

      def self.convert(file)
        instance.convert(file)
      end

      def initialize(roots)
        @cache = {}
        @roots = normalize(roots)
      end

      def convert(file)
        @cache[file] ||= begin
          relative_file = file
          @roots.each do |root|
            relative_file = file.gsub(/^#{root}/, ".")
            break relative_file if relative_file.start_with?(".")
          end
          relative_file
        end
      end

      private

      def normalize(paths)
        paths.map { |root| File.expand_path(root) }
      end
    end
  end
end
