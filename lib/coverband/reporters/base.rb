# frozen_string_literal: true

module Coverband
  module Reporters
    ###
    # This is the base clase for report generation
    # it helps with filtering, normalization, etc for final reprort generation
    ###
    class Base
      class << self
        include Coverband::Utils::FilePathHelper
        def report(store, _options = {})
          all_roots = Coverband.configuration.all_root_paths
          scov_style_report = get_current_scov_data_imp(store, all_roots)

          # These are extremelhy verbose but useful during coverband development, not generally for users
          # if Coverband.configuration.verbose
          #   # msg = "report:\n #{scov_style_report.inspect}"
          #   # Coverband.configuration.logger.debug msg
          # end
          scov_style_report
        end

        ###
        # Add back files that exist in the project but have no Coverage
        # This makes it easy to find and delete files with no references
        ###
        def fix_reports(reports)
          # list all files, even if not tracked by Coverband (0% coverage)
          file_patterns = ["#{Coverband.configuration.current_root}/{app,lib,config}/**/*.{rb}"]
          if Coverband.configuration.track_gems
            file_patterns.concat(Bundler.definition.specs.reject { |spec| spec.name == 'coverband' }.map(&:full_require_paths)
              .flatten.map { |path| "#{path}/**/*.{rb}" })
          end
          filtered_report_files = {}

          reports.each_pair do |report_name, report_data|
            filtered_report_files[report_name] = {}
            report_files = Coverband::Utils::Result.add_not_loaded_files(report_data, file_patterns)

            # apply coverband filters
            report_files.each_pair do |file, data|
              next if Coverband.configuration.ignore.any? { |i| file.match(i) }

              filtered_report_files[report_name][file] = data
            end
          end
          filtered_report_files
        end

        protected

        def fix_file_names(report_hash, roots)
          Coverband.configuration.logger.info "fixing root: #{roots.join(', ')}" if Coverband.configuration.verbose

          # normalize names across servers
          report_hash.each_with_object({}) do |(name, report), fixed_report|
            fixed_report[name] = {}
            report.each_pair do |key, vals|
              filename = relative_path_to_full(key, roots)
              fixed_report[name][filename] = if fixed_report[name].key?(filename) && fixed_report[name][filename]['data'] && vals['data']
                                               merged_data = merge_arrays(fixed_report[name][filename]['data'], vals['data'])
                                               vals['data'] = merged_data
                                               vals
                                             else
                                               vals
                                             end
            end
          end
        end

        # > merge_arrays([nil,0,0,1,0,1],[nil,nil,0,1,0,0])
        # > [nil,0,0,1,0,1]
        def merge_arrays(first, second)
          merged = []
          longest = first.length > second.length ? first : second

          longest.each_with_index do |_line, index|
            merged[index] = if first[index] || second[index]
                              (first[index].to_i + second[index].to_i)
                            end
          end

          merged
        end

        ###
        # why do we need to merge covered files data?
        # basically because paths on machines or deployed hosts could be different, so
        # two different keys could point to the same filename or `line_key`
        # TODO: think we are filtering based on ignore while sending to the store
        # and as we also pull it out here
        ###
        def get_current_scov_data_imp(store, roots)
          scov_style_report = {}
          store.get_coverage_report.each_pair do |name, data|
            data.each_pair do |key, line_data|
              next if Coverband.configuration.ignore.any? { |i| key.match(i) }
              next unless line_data

              scov_style_report[name] = {} unless scov_style_report.key?(name)
              scov_style_report[name][key] = line_data
            end
          end

          scov_style_report = fix_file_names(scov_style_report, roots)
          scov_style_report
        end
      end
    end
  end
end
