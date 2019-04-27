# frozen_string_literal: true

####
# Helper functions for shared logic related to file path manipulation
####
module Coverband
  module Utils
    module FilePathHelper
      extend self
      ###
      # Takes a full path and converts to a relative path
      ###
      def full_path_to_relative(full_path)
        relative_filename = full_path
        Coverband.configuration.all_root_paths.each do |root|
          relative_filename = relative_filename.gsub(/^#{root}/, './')
          # once we have a relative path break out of the loop
          break if relative_filename.start_with? './'
        end
        relative_filename
      end

      ###
      # relative_path_to_full code takes:
      # relative_path: which is a full path the same as reported by Coverage
      # roots: if a collection of all possible full app paths
      #    EX: [Coverband.configuration.root_paths, "#{current_root}/"]
      # The LAST item should be the current file system root
      # it expands that expands and adds a '/' as that isn't there from Dir.pwd
      #
      # NOTEs on configuration.root_paths usage
      # strings: matching is pretty simple for full string paths
      # regex: to get regex to work for changing deploy directories
      #        the regex must be double escaped in double quotes
      #          (if using \d for example)
      #        or use single qoutes
      #        example: '/box/apps/app_name/releases/\d+/'
      #        example: '/var/local/company/company.d/[0-9]*/'
      ###
      def relative_path_to_full(relative_path, roots)
        relative_filename = relative_path
        local_filename = relative_filename
        roots.each do |root|
          relative_filename = relative_filename.gsub(/^#{root}/, './')
        end
        # the filename for our reports is expected to be a full path.
        # roots.last should be roots << current_root}/
        # a fully expanded path of config.root
        # filename = filename.gsub('./', roots.last)
        # above only works for app files
        # we need to rethink some of this logic
        # gems aren't at project root and can have multiple locations
        local_root = roots.find { |root| File.exist?(relative_filename.gsub('./', root)) }
        local_root ? relative_filename.gsub('./', local_root) : local_filename
      end
    end
  end
end
