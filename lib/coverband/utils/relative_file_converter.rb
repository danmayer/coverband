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
        @roots_regexp = Regexp.union(convert_roots(roots))
      end

      def convert(file)
        @cache[file] ||= begin
          relative_file = file.sub(@roots_regexp, "./")

          if relative_file == file && !file.start_with?(".") && File.exist?(file)
            real_file = File.realpath(file)
            new_relative_file = real_file.sub(@roots_regexp, "./")
            relative_file = ((new_relative_file == real_file) ? file : new_relative_file)
          end

          relative_file
        end
      end

      private

      def convert_roots(roots)
        roots.flat_map { |root|
          items = []
          expanded = File.expand_path(root)
          expanded += "/" unless expanded.end_with?("/")
          items << /^#{Regexp.escape(expanded)}/

          if File.exist?(root)
            real = File.realpath(root)
            real += "/" unless real.end_with?("/")
            items << /^#{Regexp.escape(real)}/
          end
          items
        }.uniq
      end
    end
  end
end
