# frozen_string_literal: true

#
# Applies the configured groups to the given array of Coverband::SourceFile items
#
module Coverband
  module Utils
    class FileGroups
      def initialize(files)
        @grouped = {}
        @files = files
        filter_to_groups
      end

      def grouped_results
        @grouped
      end

      private

      def filter_to_groups
        grouped_files = []
        Coverband.configuration.groups.each do |name, filter|
          if name == 'Gems'
            gem_lists = gem_files(name, filter)
            grouped_files.concat(gem_lists.flatten) if gem_lists.flatten.any?
          else
            app_files(name, filter)
            grouped_files += @grouped[name]
          end
        end
        if !Coverband.configuration.groups.empty? && !(other_files = @files.reject do |source_file|
                                                         grouped_files.include?(source_file)
                                                       end).empty?
          @grouped['Ungrouped'] = Coverband::Utils::FileList.new(other_files)
        end
      end

      def gem_files(name, filter)
        grouped_gems = @files.select { |source_file| source_file.filename =~ /#{filter}/ }.group_by(&:gem_name)
        gem_lists = grouped_gems.values.map { |gem_files| Coverband::Utils::FileList.new(gem_files) }
        @grouped[name] = Coverband::Utils::GemList.new(gem_lists) if gem_lists.flatten.any?
        gem_lists
      end

      def app_files(name, filter)
        @grouped[name] = Coverband::Utils::FileList.new(@files.select do |source_file|
          source_file.filename =~ /#{filter}/ && source_file.filename !~ /#{Coverband.configuration.gem_paths.first}/
        end)
      end
    end
  end
end
