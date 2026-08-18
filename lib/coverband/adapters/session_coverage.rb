# frozen_string_literal: true

require_relative "../storage/session"

module Coverband
  module Adapters
    ###
    # Coverage on top of the merge protocol, shared by the adapters that keep it
    # in one document per type.
    #
    # Counts are additive, so a dropped write cannot be repaired by writing
    # again: re-applying a sum double counts. The per writer sequences in
    # Storage::Session are what make the retry safe, which is why both adapters
    # go through here rather than each merging on their own.
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

      # the pointers this store will consult, so a cycle can fetch them in one
      # round trip instead of one small read per document

      def pointer_sessions
        Coverband::TYPES.map { |session_type| build_session(session_type) }
      end

      def prefetch_pointers!(extra_sessions = [])
        Storage::Session.prefetch_pointers(storage_target, pointer_sessions + Array(extra_sessions))
      end

      # whether every type actually cleared: a reset whose pointer write did not
      # land leaves the old generation authoritative, and callers have to be able
      # to say so rather than report success

      def clear!
        results = Coverband::TYPES.map { |type| session_for(type).reset }
        @cached_file_count = nil
        results.all?
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

      # expanded here once: re-expanding on a retry would hand an old delta a
      # fresh timestamp and let it slip past a tombstone recorded in between

      def save_report(report)
        session_for(type).record(own_expanded_report(report))
        @cached_file_count = nil
      end

      def save_coverage(report, local_type = nil)
        session_for(local_type || type).record(own_expanded_report(report))
      end

      def file_count
        coverage(Coverband::RUNTIME_TYPE, skip_hash_check: true).keys.length
      end

      def data_loss
        Coverband::TYPES.map { |type| session_for(type).data_loss }.compact.first
      end

      # gives up the repair those held reports would have done, in exchange for
      # the memory; benchmarks and shutdown only

      def discard_pending!
        Coverband::TYPES.each { |type| session_for(type).discard_pending! }
      end

      private

      ###
      # A delta has to survive being applied, because re-applying it is how a
      # lost update gets repaired. expand_report hands the delta the caller's own
      # line arrays and array_add sums into them in place unless they are frozen,
      # so an unfrozen payload is overwritten with the merged document total on
      # its first apply -- and a repair after that carries the whole document
      # back in and doubles it, once per repair.
      #
      # Freezing selects array_add's copying branch, so the delta keeps this
      # process's own counts and the caller's report is left alone.
      ###
      def own_expanded_report(report)
        expand_report(report).each_value do |entry|
          entry[Base::DATA_KEY] = entry[Base::DATA_KEY].dup.freeze
          entry.freeze
        end
      end

      def sessions
        @sessions ||= {}
      end

      # both types are built together, or reporting one would allocate the
      # other's keys later at an unpredictable moment

      def session_for(local_type)
        local_type ||= type
        Coverband::TYPES.each { |session_type| build_session(session_type) }
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

      # line hits sum, so this merge is not idempotent and the applied sequence
      # guard is what keeps a retry from inflating the counts

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
