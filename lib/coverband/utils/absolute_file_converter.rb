# frozen_string_literal: true

module Coverband
  module Utils
    class AbsoluteFileConverter
      def initialize(roots)
        @cache = {}
        @roots = roots.map { |root| "#{File.expand_path(root)}/" }
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
          @roots.each do |root|
            relative_filename = relative_filename.sub(/^#{root}/, "./")
            # once we have a relative path break out of the loop
            break if relative_filename.start_with? "./"
          end
          # the filename for our reports is expected to be a full path.
          # roots.last should be roots << current_root}/
          # a fully expanded path of config.root
          # filename = filename.gsub('./', roots.last)
          # above only works for app files
          # we need to rethink some of this logic
          # gems aren't at project root and can have multiple locations
          local_root = @roots.find { |root|
            File.exist?(relative_filename.gsub("./", root))
          }
          local_root ? relative_filename.gsub("./", local_root) : local_filename
        end
      end
    end
  end
end
