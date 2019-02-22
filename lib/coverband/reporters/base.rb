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

          if Coverband.configuration.verbose
            msg = "report:\n #{scov_style_report.inspect}"
            Coverband.configuration.logger.debug msg
          end
          scov_style_report
        end

        protected

        def fix_file_names(report_hash, roots)
          if Coverband.configuration.verbose
            Coverband.configuration.logger.info "fixing root: #{roots.join(', ')}"
          end

          # normalize names across servers
          report_hash.each_with_object({}) do |(key, vals), fixed_report|
            filename = relative_path_to_full(key, roots)
            fixed_report[filename] = if fixed_report.key?(filename) && fixed_report[filename]['data'] && vals['data']
                                       merged_data = merge_arrays(fixed_report[filename]['data'], vals['data'])
                                       vals['data'] = merged_data
                                       vals
                                     else
                                       vals
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
          store.coverage.each_pair do |key, line_data|
            next if Coverband.configuration.ignore.any? { |i| key.match(i) }
            next unless line_data
            scov_style_report[key] = line_data
          end

          scov_style_report = fix_file_names(scov_style_report, roots)
          scov_style_report
        end
      end
    end
  end
end
