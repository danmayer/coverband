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
        @roots = convert_roots(roots)
      end

      def convert(file)
        @cache[file] ||= begin
          relative_file = file
          @roots.each do |root|
            if root.match?(file)
              relative_file = file.sub(root, "./")
              break
            end
          end

          if relative_file == file && !file.start_with?(".") && File.exist?(file)
            real_file = File.realpath(file)
            @roots.each do |root|
              if root.match?(real_file)
                new_relative_file = real_file.sub(root, "./")
                relative_file = (new_relative_file == file ? file : new_relative_file)
                break
              end
            end
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
