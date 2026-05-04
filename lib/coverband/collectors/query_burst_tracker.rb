# frozen_string_literal: true

require "json"
require "set"
require "singleton"

module Coverband
  module Collectors
    # Lightweight SQL burst tracker for production runtime behavior.
    # Aggregates per controller action / job class and persists compact stats.
    class QueryBurstTracker < AbstractTracker
      REPORT_ROUTE = "query_bursts_tracker"
      TITLE = "Query Bursts"
      CONTEXT_STACK_KEY = :coverband_query_burst_context_stack
      IGNORED_SQL_NAMES = %w[SCHEMA CACHE TRANSACTION].freeze

      def initialize(options = {})
        super
        @pending_stats = {}
      end

      def railtie!
        ActiveSupport::Notifications.subscribe("start_processing.action_controller") do |_name, _start, _finish, _id, payload|
          start_context(:controller, controller_key(payload))
        end

        ActiveSupport::Notifications.subscribe("process_action.action_controller") do |_name, _start, _finish, _id, payload|
          finish_context(:controller, controller_key(payload))
        end

        ActiveSupport::Notifications.subscribe("perform_start.active_job") do |_name, _start, _finish, _id, payload|
          start_context(:job, job_key(payload))
        end

        ActiveSupport::Notifications.subscribe("perform.active_job") do |_name, _start, _finish, _id, payload|
          finish_context(:job, job_key(payload))
        end

        ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, start, finish, _id, payload|
          next if ignore_sql_event?(payload)

          record_sql_event(duration_ms(start, finish))
        end
      end

      def track_key(payload)
        key = payload[:key] || payload["key"]
        return unless key

        queries = (payload[:queries] || payload["queries"] || 0).to_i
        sql_time_ms = (payload[:sql_time_ms] || payload["sql_time_ms"] || 0.0).to_f
        record_observation(key, queries, sql_time_ms)
      end

      def used_keys
        return {} unless redis_store

        stats_hash = redis_store.hgetall(tracker_key)
        stats_hash.each_with_object({}) do |(key, stats_json), used|
          stats = parse_stats(stats_json)
          used[key] = stats["last_seen"].to_i
        end
      end

      def used_key_stats
        return {} unless redis_store

        stats_hash = redis_store.hgetall(tracker_key)
        stats_hash
          .transform_values { |stats_json| parse_stats(stats_json) }
          .sort_by { |key, stats| [-stats["threshold_hits"].to_i, -stats["total_sql_time_ms"].to_f, key] }
          .to_h
      end

      def unused_keys(_used_keys = nil)
        []
      end

      def all_keys
        []
      end

      def as_json
        {
          tracking_since: tracking_since,
          thresholds: {
            query_count: query_count_threshold,
            sql_time_ms: sql_time_threshold_ms
          },
          used_keys: used_key_stats
        }.to_json
      end

      def save_report
        return unless redis_store
        return if @pending_stats.empty?

        redis_store.set(tracker_time_key, Time.now.to_i) unless @one_time_timestamp || tracker_time_key_exists?
        @one_time_timestamp = true

        existing_stats = redis_store.hgetall(tracker_key)
        merged = @pending_stats.each_with_object({}) do |(key, pending), h|
          existing = parse_stats(existing_stats[key])
          h[key] = merge_stats(existing, pending).to_json
        end

        redis_store.hset(tracker_key, merged) if merged.any?
        @pending_stats.clear
      rescue => e
        logger&.error "Coverband: #{self.class.name} failed to store, error #{e.class.name} info #{e.message}"
      end

      private

      def start_context(type, key)
        return unless key

        context_stack << {
          type: type,
          key: key,
          queries: 0,
          sql_time_ms: 0.0
        }
      end

      def finish_context(type, key)
        context = pop_context(type, key)
        return unless context

        record_observation(context[:key], context[:queries], context[:sql_time_ms])
      end

      def pop_context(type, key)
        index = context_stack.rindex { |context| context[:type] == type && context[:key] == key }
        return unless index

        context_stack.delete_at(index)
      end

      def record_sql_event(ms)
        return if context_stack.empty?

        context = context_stack.last
        context[:queries] += 1
        context[:sql_time_ms] += ms
      end

      def record_observation(key, query_count, sql_time_ms)
        key = key.to_s
        stats = @pending_stats[key] || default_stats

        stats["requests"] += 1
        stats["total_queries"] += query_count
        stats["total_sql_time_ms"] += sql_time_ms
        stats["max_queries"] = [stats["max_queries"], query_count].max
        stats["max_sql_time_ms"] = [stats["max_sql_time_ms"], sql_time_ms].max

        now = Time.now.to_i
        stats["last_seen"] = now
        stats["last_event"] = {
          "queries" => query_count,
          "sql_time_ms" => sql_time_ms.round(3),
          "at" => now
        }
        stats["threshold_hits"] += 1 if threshold_hit?(query_count, sql_time_ms)

        @pending_stats[key] = stats
        @logged_keys << key
      end

      def threshold_hit?(query_count, sql_time_ms)
        query_count >= query_count_threshold || sql_time_ms >= sql_time_threshold_ms
      end

      def default_stats
        {
          "requests" => 0,
          "total_queries" => 0,
          "total_sql_time_ms" => 0.0,
          "max_queries" => 0,
          "max_sql_time_ms" => 0.0,
          "threshold_hits" => 0,
          "last_seen" => nil,
          "last_event" => nil
        }
      end

      def merge_stats(existing, pending)
        {
          "requests" => existing["requests"].to_i + pending["requests"].to_i,
          "total_queries" => existing["total_queries"].to_i + pending["total_queries"].to_i,
          "total_sql_time_ms" => existing["total_sql_time_ms"].to_f + pending["total_sql_time_ms"].to_f,
          "max_queries" => [existing["max_queries"].to_i, pending["max_queries"].to_i].max,
          "max_sql_time_ms" => [existing["max_sql_time_ms"].to_f, pending["max_sql_time_ms"].to_f].max,
          "threshold_hits" => existing["threshold_hits"].to_i + pending["threshold_hits"].to_i,
          "last_seen" => [existing["last_seen"].to_i, pending["last_seen"].to_i].max,
          "last_event" => latest_event(existing["last_event"], pending["last_event"])
        }
      end

      def latest_event(existing_event, pending_event)
        return pending_event unless existing_event
        return existing_event unless pending_event

        if existing_event["at"].to_i >= pending_event["at"].to_i
          existing_event
        else
          pending_event
        end
      end

      def parse_stats(stats_json)
        return default_stats unless stats_json

        parsed = JSON.parse(stats_json)
        default_stats.merge(parsed)
      rescue JSON::ParserError
        default_stats
      end

      def context_stack
        Thread.current[CONTEXT_STACK_KEY] ||= []
      end

      def ignore_sql_event?(payload)
        return true if payload[:cached]

        name = payload[:name].to_s
        IGNORED_SQL_NAMES.include?(name)
      end

      def duration_ms(start, finish)
        (finish - start) * 1000.0
      end

      def controller_key(payload)
        controller = payload[:controller] || payload.dig(:params, "controller")
        action = payload[:action]
        return unless controller && action

        "controller:#{controller}##{action}"
      end

      def job_key(payload)
        job = payload[:job]
        return unless job

        queue_name = if job.respond_to?(:queue_name)
          job.queue_name
        end
        queue_suffix = queue_name ? " queue:#{queue_name}" : ""
        "job:#{job.class.name}#{queue_suffix}"
      end

      def query_count_threshold
        Coverband.configuration.query_burst_query_count_threshold.to_i
      end

      def sql_time_threshold_ms
        Coverband.configuration.query_burst_sql_time_threshold_ms.to_f
      end

      def concrete_target
        []
      end
    end
  end
end
