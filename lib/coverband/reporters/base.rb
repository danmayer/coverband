# frozen_string_literal: true

module Coverband
  module Reporters
    ###
    # This is the base clase for report generation
    # it helps with filtering, normalization, etc for final report generation
    ###
    class Base
      class << self
        DATA_KEY = "data"

        def report(store, options = {})
          all_roots = Coverband.configuration.all_root_paths
          get_current_scov_data_imp(store, all_roots, options)

          # These are extremelhy verbose but useful during coverband development, not generally for users
          # Only available by uncommenting this mode is never released
          # if Coverband.configuration.verbose
          #   # msg = "report:\n #{scov_style_report.inspect}"
          #   # Coverband.configuration.logger.debug msg
          # end
        end

        ###
        # Add back files that exist in the project but have no Coverage
        # This makes it easy to find and delete files with no references
        ###
        def fix_reports(reports)
          # list all files, even if not tracked by Coverband (0% coverage)
          tracked_glob = Coverband.configuration.tracked_search_paths
          filtered_report_files = {}

          reports.each_pair do |report_name, report_data|
            filtered_report_files[report_name] = {}
            report_files = Coverband::Utils::Result.add_not_loaded_files(report_data, tracked_glob)

            # apply coverband filters
            report_files.each_pair do |file, data|
              next if Coverband.configuration.ignore.any? { |i| file.match?(i) }

              filtered_report_files[report_name][file] = data
            end
          end
          filtered_report_files
        end

        protected

        def fix_file_names(report_hash, roots)
          Coverband.configuration.logger.debug "fixing root: #{roots.join(", ")}" if Coverband.configuration.verbose

          # normalize names across servers
          report_hash.each_with_object({}) do |(name, report), fixed_report|
            fixed_report[name] = {}
            report.each_pair do |key, vals|
              filename = Coverband::Utils::AbsoluteFileConverter.convert(key)
              fixed_report[name][filename] = if fixed_report[name].key?(filename) && fixed_report[name][filename][DATA_KEY] && vals[DATA_KEY]
                merged_data = merge_arrays(fixed_report[name][filename][DATA_KEY], vals[DATA_KEY])
                vals[DATA_KEY] = merged_data
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
          longest = (first.length > second.length) ? first : second

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
        # this happens when deployment has a dynamic path or the path change during deployment (hot code reload)
        # TODO: think we are filtering based on ignore while sending to the store
        # and as we also pull it out here
        ###
        def get_current_scov_data_imp(store, roots, options = {})
          scov_style_report = {}
          store.get_coverage_report(options).each_pair do |name, data|
            data.each_pair do |key, line_data|
              next if Coverband.configuration.ignore.any? { |i| key.match?(i) }
              next unless line_data

              scov_style_report[name] = {} unless scov_style_report.key?(name)
              scov_style_report[name][key] = line_data
            end
          end

          fix_file_names(scov_style_report, roots)
        end
      end
    end
  end
end
