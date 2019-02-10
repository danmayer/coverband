# frozen_string_literal: true

module Coverband
  module Reporters
    ###
    # This is the base clase for report generation
    # it helps with filtering, normalization, etc for final reprort generation
    ###
    class Base
      class << self
        def report(store, _options = {})
          scov_style_report = get_current_scov_data_imp(store, root_paths)

          if Coverband.configuration.verbose
            msg = "report:\n #{scov_style_report.inspect}"
            Coverband.configuration.logger.debug msg
          end
          scov_style_report
        end

        protected

        def root_paths
          roots = Coverband.configuration.root_paths
          roots += Coverband.configuration.gem_paths if Coverband.configuration.track_gems
          roots << "#{current_root}/"
          roots
        end

        def current_root
          File.expand_path(Coverband.configuration.root)
        end

        def fix_file_names(report_hash, roots)
          if Coverband.configuration.verbose
            Coverband.configuration.logger.info "fixing root: #{roots.join(', ')}"
          end

          # normalize names across servers
          report_hash.each_with_object({}) do |(key, vals), fixed_report|
            filename = filename_from_key(key, roots)
            fixed_report[filename] = if fixed_report.key?(filename)
                                       merge_arrays(fixed_report[filename], vals)
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
        # filename_from_key code takes:
        # key: which is a full path the same as reported by Coverage
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
        def filename_from_key(key, roots)
          relative_filename = key
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

        ###
        # why do we need to merge covered files data?
        # basically because paths on machines or deployed hosts could be different, so
        # two different keys could point to the same filename or `line_key`
        # this logic should be pushed to base report
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
