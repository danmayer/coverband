# frozen_string_literal: true

#
# Applies the configured groups to the given array of Coverband::SourceFile items
#
module Coverband
  module Utils
    class FileGroups
      def initialize(files)
        @grouped = {}
        filter_to_groups(files)
      end

      def grouped_results
        @grouped
      end

      private

      def filter_to_groups(files)
        grouped_files = []
        grouped_gems = {}
        gem_lists = []
        Coverband.configuration.groups.each do |name, filter|
          if name == 'Gems'
            grouped_gems = files.select { |source_file| source_file.filename =~ /#{filter}/ }.group_by(&:gem_name)
            gem_lists = grouped_gems.values.map { |gem_files| Coverband::Utils::FileList.new(gem_files) }
            grouped_files.concat(gem_lists.flatten)
            @grouped[name] = Coverband::Utils::GemList.new(gem_lists)
          else
            @grouped[name] = Coverband::Utils::FileList.new(files.select do |source_file|
              source_file.filename =~ /#{filter}/
            end)
            grouped_files += @grouped[name]
          end
        end
        if !Coverband.configuration.groups.empty? && !(other_files = files.reject do |source_file|
                                                         grouped_files.include?(source_file)
                                                       end).empty?
          @grouped['Ungrouped'] = Coverband::Utils::FileList.new(other_files)
        end
      end
    end
  end
end
