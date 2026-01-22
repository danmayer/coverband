# frozen_string_literal: true

module Coverband
  module Utils
    class AbsoluteFileConverter
      def initialize(roots)
        @cache = {}
        @roots = convert_roots(roots)
      end

      def self.instance
        @instance ||= new(Coverband.configuration.all_root_paths)
      end

      def self.reset
        @instance = nil
      end

      def self.convert(relative_path)
        instance.convert(relative_path)
      end

      def convert(relative_path)
        @cache[relative_path] ||= begin
          relative_filename = relative_path
          local_filename = relative_filename
          @roots.each do |root, root_regexp|
            if relative_filename.match?(root_regexp)
              relative_filename = relative_filename.sub(root_regexp, "./")
              # once we have a relative path break out of the loop
              break
            end
          end

          if relative_filename == local_filename && File.exist?(local_filename)
            real_filename = File.realpath(local_filename)
            @roots.each do |root, root_regexp|
              if real_filename.match?(root_regexp)
                relative_filename = real_filename.sub(root_regexp, "./")
                # once we have a relative path break out of the loop
                break
              end
            end
          end

          # the filename for our reports is expected to be a full path.
          # roots.last should be roots << current_root}/
          # a fully expanded path of config.root
          # filename = filename.gsub('./', roots.last)
          # above only works for app files
          # we need to rethink some of this logic
          # gems aren't at project root and can have multiple locations
          local_root = @roots.find { |root, _root_regexp|
            File.exist?(relative_filename.gsub("./", root))
          }&.first
          local_root ? relative_filename.gsub("./", local_root) : local_filename
        end
      end

      private

      def convert_roots(roots)
        roots.flat_map { |root|
          items = []
          expanded = "#{File.expand_path(root)}/"
          items << [expanded, /^#{expanded}/]

          if File.exist?(root)
            real = "#{File.realpath(root)}/"
            items << [real, /^#{Regexp.escape(real)}/]
          end
          items
        }.uniq
      end
    end
  end
end
