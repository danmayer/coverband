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
        @roots = normalize(roots).map { |root| /^#{root}/ }
      end

      def convert(file)
        @cache[file] ||= begin
          relative_file = file
          @roots.each do |root|
            relative_file = file.gsub(root, ".")
            break relative_file if relative_file.start_with?(".")
          end

          if relative_file == file && File.exist?(file)
            real_file = File.realpath(file)
            @roots.each do |root|
              relative_file = real_file.gsub(root, ".")
              break relative_file if relative_file.start_with?(".")
            end
          end

          relative_file
        end
      end

      private

      def normalize(paths)
        paths.flat_map do |root|
          [
            File.expand_path(root),
            (File.realpath(root) if File.exist?(root))
          ].compact
        end.uniq
      end
    end
  end
end
