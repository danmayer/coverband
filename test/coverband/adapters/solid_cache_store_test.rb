# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))

###
# Solid Cache is how this adapter reaches Postgres, MySQL, and SQLite, and it is
# the one backend whose own behaviour interacts with the protocol rather than
# just hosting it. Every read and write becomes SQL, which is what makes the
# query burst feedback loop and the ActiveRecord availability paths real.
#
# SQLite is enough to exercise all of that.
###
###
# ENV gated, and for a reason: solid_cache ships a Rails engine, so loading it
# defines Rails constants that change how the rest of the suite behaves in the
# same process. Run it on its own with `rake test:solid_cache`.
###
if ENV["COVERBAND_SOLID_CACHE"]
  begin
    require "rails" # solid_cache ships a Rails engine
    require "active_record"
    require "sqlite3"
    require "solid_cache"

    ###
    # Solid Cache autoloads its models through a Rails engine. There is no Rails
    # app here, so they are loaded directly from the gem.
    ###
    solid_cache_models = File.join(Gem::Specification.find_by_name("solid_cache").gem_dir, "app", "models")
    loader = Zeitwerk::Loader.new
    loader.push_dir(solid_cache_models)
    loader.setup
    loader.eager_load

    SOLID_CACHE_AVAILABLE = true
  rescue LoadError, NameError
    SOLID_CACHE_AVAILABLE = false
  end

  if SOLID_CACHE_AVAILABLE
    class SolidCacheStoreTest < Minitest::Test
      def setup
        super
        @db = File.join(Dir.tmpdir, "coverband_solid_cache_#{Process.pid}_#{rand(10_000)}.sqlite3")
        ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: @db)
        create_schema
        # no shard configuration: the default connection is the store
        @cache = SolidCache::Store.new
        @store = Coverband::Adapters::ActiveSupportCacheStore.new(@cache, cache_namespace: "coverband_test")
      end

      def teardown
        ActiveRecord::Base.connection_pool.disconnect!
        FileUtils.rm_f(@db)
        super
      end

      def test_coverage_round_trip_through_the_database
        mock_file_hash
        @store.save_report(basic_coverage)
        assert_equal example_line, @store.coverage["app_path/dog.rb"]["data"]
      end

      def test_concurrent_writers_converge_without_double_counting
        mock_file_hash
        other = Coverband::Adapters::ActiveSupportCacheStore.new(@cache, cache_namespace: "coverband_test")

        @store.save_report("app_path/dog.rb" => [1, 0, 0])
        other.save_report("app_path/dog.rb" => [0, 1, 0])
        3.times do
          @store.save_report({})
          other.save_report({})
        end

        assert_equal [1, 1, 0], @store.coverage["app_path/dog.rb"]["data"]
      end

      ###
      # Solid Cache is expected to give a genuine atomic create, which is what
      # removes the pointer initialization race entirely on this backend.
      ###
      def test_pointer_creation_is_atomic
        target = Coverband::Storage::Target.new(@cache)
        assert target.atomic_create?, "Solid Cache should support an atomic create"

        assert target.create("coverband_test.atomic", "first")
        refute target.create("coverband_test.atomic", "second"), "a second create must not win"
        assert_equal "first", target.read("coverband_test.atomic")
      end

      def test_pointers_are_batched_in_one_round_trip
        mock_file_hash
        Coverband::TYPES.each do |type|
          @store.type = type
          @store.save_report(basic_coverage)
        end

        fresh = Coverband::Adapters::ActiveSupportCacheStore.new(@cache, cache_namespace: "coverband_test")
        sessions = fresh.pointer_sessions
        found = Coverband::Storage::Target.new(@cache).read_multi(*sessions.map(&:pointer_key))

        assert_equal sessions.length, found.length, "every pointer should come back from one read_multi"

        # and the batch primes them, so no session reads its pointer again
        fresh.prefetch_pointers!
        sessions.each do |session|
          refute_nil session.instance_variable_get(:@primed_pointer), "#{session.pointer_key} should be primed"
        end
      end

      ###
      # Coverband's own storage queries must not be attributed to whatever request
      # triggered the report, or they inflate the very counts the tracker exists
      # to flag.
      ###
      def test_storage_sql_is_not_attributed_to_the_request
        Coverband::Collectors::QueryBurstTracker.stubs(:supported_version?).returns(true)
        tracker = Coverband::Collectors::QueryBurstTracker.new(store: @store)
        mock_file_hash

        tracker.send(:start_context, :controller, "controller:dogs#index")
        @store.save_report(basic_coverage) # real SQL, inside a tracked request
        tracker.send(:finish_context, :controller, "controller:dogs#index")

        stats = tracker.instance_variable_get(:@pending_stats)["controller:dogs#index"]
        assert_equal 0, stats["total_queries"], "Coverband's own SQL must not count against the action"
      end

      ###
      # Reporting can run before ActiveRecord is established, or after it is torn
      # down, and neither may raise into the host application.
      ###
      def test_reads_degrade_when_active_record_is_unavailable
        mock_file_hash
        @store.save_report(basic_coverage)
        ActiveRecord::Base.connection_pool.disconnect!
        ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: "/nonexistent/path.sqlite3")

        assert_equal({}, @store.coverage)
        assert_nil @store.size
      end

      def test_reads_degrade_when_the_schema_is_missing
        ActiveRecord::Base.connection.drop_table(:solid_cache_entries)

        assert_equal({}, @store.coverage)
        assert_equal 0, @store.file_count
      end

      ###
      # Solid Cache compresses values itself, so the adapter should not be
      # prescribing a compress option on top of it.
      ###
      def test_large_documents_round_trip
        mock_file_hash
        big = {"app_path/dog.rb" => Array.new(5_000) { |i| i % 7 }}
        @store.save_report(big)
        assert_equal 5_000, @store.coverage["app_path/dog.rb"]["data"].length
      end

      private

      def create_schema
        ActiveRecord::Schema.verbose = false
        ActiveRecord::Schema.define do
          create_table :solid_cache_entries, force: true do |t|
            t.binary :key, null: false, limit: 1024
            t.binary :value, null: false, limit: 536_870_912
            t.datetime :created_at, null: false
            t.integer :key_hash, null: false, limit: 8
            t.integer :byte_size, null: false, limit: 4
            t.index [:key_hash], unique: true
            t.index [:byte_size]
          end
        end
      end
    end
  end

end
