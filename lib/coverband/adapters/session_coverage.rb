# frozen_string_literal: true

require_relative "../storage/session"

module Coverband
  module Adapters
    ###
    # Coverage storage on top of the merge protocol, shared by the adapters that
    # keep coverage in a single document per type.
    #
    # Coverage counts are additive, so a write another process drops cannot be
    # repaired by simply writing again: re-applying a sum double counts. The
    # per writer sequences in Coverband::Storage::Session are what make the
    # retry safe, which is why both adapters go through here rather than each
    # merging on their own.
    #
    # Including classes provide #storage_target and #coverage_key_base.
    ###
    module SessionCoverage
      # coverage deltas are large, so they get a tighter pending bound than the
      # trackers do
      COVERAGE_MAX_ENTRIES = 2

      def persistent_coverage?
        true
      end

      def clear!
        Coverband::TYPES.each { |type| session_for(type).reset }
        @cached_file_count = nil
      end

      def clear_file!(filename)
        relative = Utils::RelativeFileConverter.convert(filename)
        Coverband::TYPES.each do |type|
          session_for(type).delete_entry(relative)
          session_for(type).delete_entry(filename)
        end
        @cached_file_count = nil
      end

      def size
        session_for(type).stored_size
      end

      def type=(type)
        super
        @cached_file_count = nil
      end

      def coverage(local_type = nil, opts = {})
        local_type ||= opts.key?(:override_type) ? opts[:override_type] : type
        data = session_for(local_type).entries.dup
        unless opts[:skip_hash_check]
          data.delete_if { |file_path, file_data| file_hash(file_path) != file_data["file_hash"] }
        end
        data
      end

      ###
      # Expanding the report here, once, is deliberate. Re-expanding it on a
      # retry would hand an old delta a fresh timestamp and let it slip past a
      # tombstone recorded in between.
      ###
      def save_report(report)
        session_for(type).record(expand_report(report.dup))
        @cached_file_count = nil
      end

      def save_coverage(report, local_type = nil)
        session_for(local_type || type).record(expand_report(report.dup))
      end

      def file_count
        coverage(Coverband::RUNTIME_TYPE, skip_hash_check: true).keys.length
      end

      def data_loss
        Coverband::TYPES.map { |type| session_for(type).data_loss }.compact.first
      end

      ###
      # Unconfirmed reports are held so a conflicting write can be repaired next
      # cycle. This gives that up in exchange for the memory, and is only for
      # benchmarks and shutdown paths.
      ###
      def discard_pending!
        Coverband::TYPES.each { |type| session_for(type).discard_pending! }
      end

      private

      def sessions
        @sessions ||= {}
      end

      ###
      # Both types are built together on first use. Reporting one type would
      # otherwise allocate the other's keys later, at an unpredictable moment.
      ###
      def session_for(local_type)
        local_type ||= type
        built = Coverband::TYPES.map { |session_type| build_session(session_type) }
        Storage::Session.prefetch_pointers(storage_target, built) unless @pointers_prefetched
        @pointers_prefetched = true
        build_session(local_type)
      end

      def build_session(local_type)
        sessions[local_type] ||= Storage::Session.new(
          target: storage_target,
          key_base: coverage_key_base(local_type),
          merger: coverage_merger,
          logger: Coverband.configuration.logger,
          max_entries: COVERAGE_MAX_ENTRIES,
          grace_seconds: grace_seconds
        )
      end

      ###
      # Line hits sum, so this merge is not idempotent and the applied sequence
      # guard is what keeps a retry from inflating the counts.
      ###
      def coverage_merger
        @coverage_merger ||= lambda do |doc, delta|
          incoming = delta.payload.reject do |file, _data|
            doc.tombstoned?(file, delta.tombstone_epoch)
          end
          doc.payload.replace(merge_reports(incoming.dup, doc.payload, skip_expansion: true))
        end
      end

      def grace_seconds
        Coverband.configuration.background_reporting_sleep_seconds * 2
      rescue
        1200
      end
    end
  end
end
