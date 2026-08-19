# frozen_string_literal: true

require File.expand_path("../../test_helper", File.dirname(__FILE__))
require "rake"

Rake::Task.define_task(:environment)
load File.expand_path("../../../lib/coverband/utils/tasks.rb", __dir__)

###
# Cleanup reclaims keys nothing points at any more. The risk in a task that
# deletes by pattern is deleting something that was never ours, so that is what
# these check.
###
class CleanupTasksTest < Minitest::Test
  def setup
    super
    @redis = Coverband::Test.redis
    Rake::Task.tasks.each(&:reenable)
  end

  def test_clear_orphans_keeps_the_live_generation
    store = Coverband.configuration.store
    mock_file_hash
    store.save_report(basic_coverage)

    live_key = store.send(:session_for, Coverband::RUNTIME_TYPE).send(:data_key)
    format = Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION
    orphan = "#{format}.coverage.runtime.gdeadbeefdeadbeef"
    @redis.set(orphan, "{}")

    # treat every candidate as old enough; the pointer check is what protects
    # the live generation, not its age
    Coverband::Utils::Tasks.stubs(:recently_written?).returns(false)

    Rake::Task["coverband:clear_orphans"].invoke

    assert @redis.exists?(live_key), "the generation the pointer names must survive"
    refute @redis.exists?(orphan), "a generation nothing points at must be reclaimed"
  end

  ###
  # A reset between the scan and the delete must not cost us the live document.
  # Each candidate is re-checked against its pointer at deletion time, so a
  # generation that became authoritative in the meantime is spared.
  ###
  def test_clear_orphans_spares_a_generation_that_just_became_live
    store = Coverband.configuration.store
    mock_file_hash
    store.save_report(basic_coverage)
    store.clear!
    store.save_report(basic_coverage)

    new_live = store.send(:session_for, Coverband::RUNTIME_TYPE).send(:data_key)

    Rake::Task["coverband:clear_orphans"].invoke

    assert @redis.exists?(new_live), "the current generation must never be reclaimed"
  end

  ###
  # A generation created moments ago may be one another process is about to
  # point at, so age is required before reclaiming anything.
  ###
  def test_clear_orphans_leaves_young_generations_alone
    format = Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION
    young = "#{format}.coverage.runtime.gfeedfacefeedface"
    @redis.set(young, "{}")

    Rake::Task["coverband:clear_orphans"].invoke

    assert @redis.exists?(young), "a freshly written generation must not be reclaimed"
  end

  ###
  # HashRedisStore coverage was left unchanged by 7.0, so its format version is
  # still current. A cleanup that treats it as legacy deletes live coverage.
  ###
  def test_clear_legacy_never_deletes_a_format_an_adapter_still_writes
    current = [
      Coverband::Adapters::RedisStore::REDIS_STORAGE_FORMAT_VERSION,
      Coverband::Adapters::HashRedisStore::REDIS_STORAGE_FORMAT_VERSION,
      Coverband::Adapters::ActiveSupportCacheStore::STORAGE_FORMAT_VERSION
    ]
    current.each_with_index { |format, i| @redis.set("#{format}.live_key_#{i}", "{}") }

    Rake::Task["coverband:clear_legacy"].invoke

    current.each_with_index do |format, i|
      assert @redis.exists?("#{format}.live_key_#{i}"),
        "#{format} is still written by an adapter and must never be treated as legacy"
    end
    assert_empty(Coverband::Utils::Tasks.legacy_formats & current)
  end

  ###
  # A bare "*_tracker" glob would take an application's own keys with it.
  ###
  def test_clear_legacy_leaves_unrelated_application_keys_alone
    @redis.set("my_app_tracker", "important")
    @redis.set("coverband_3_2.runtime", "{}")

    Rake::Task["coverband:clear_legacy"].invoke

    assert_equal "important", @redis.get("my_app_tracker"),
      "cleanup must be scoped to Coverband's own keys"
    refute @redis.exists?("coverband_3_2.runtime")
  end

  ###
  # A lazily configured store has nothing to resolve until Rails has loaded, so
  # a task that skips the environment fails on an unavailable cache. Every task
  # that reaches storage has to boot first.
  ###
  def test_store_touching_tasks_load_the_environment_first
    source = File.read(File.expand_path("../../../../lib/coverband/utils/tasks.rb", __FILE__))
    tasks = source.scan(/^  task :?(\w+)(?:,|\s|=)[^\n]*do\n(.*?)\n  end\n/m)

    store_touching = tasks.select do |_name, body|
      body.include?("configuration.store") || body.include?("redis_for_cleanup") ||
        body.include?("Reporters::")
    end
    refute_empty store_touching

    missing = store_touching.reject { |_name, body| body.include?("load_environment!") }
    assert_empty missing.map(&:first),
      "these tasks reach the store without booting the app first"
  end

  def test_load_environment_is_a_no_op_without_rails
    Rake::Task.stubs(:task_defined?).with("environment").returns(false)
    assert_nil Coverband::Utils::Tasks.load_environment!
  end
end
