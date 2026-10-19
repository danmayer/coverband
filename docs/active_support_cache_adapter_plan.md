# ActiveSupport Cache Storage Decision Record

Tracking issue: [#533 Build generic Active Support Cache adapter](https://github.com/danmayer/coverband/issues/533)

Status: **shipped in #652 for Coverband 7.0.0**. Follow-up release cleanup shipped in #671.

## Context

Coverband's trackers used raw Redis commands, and the default `RedisStore` used
read-modify-write updates that could lose concurrent contributions. Supporting Solid Cache,
memcached, and other `ActiveSupport::Cache::Store` implementations required both a generic
adapter and a storage protocol that did not depend on Redis-specific operations.

## Decisions

- Add `Coverband::Adapters::ActiveSupportCacheStore`, accepting either a cache instance or a
  lazy block such as `ActiveSupportCacheStore.new { Rails.cache }`.
- Use one generation pointer per independently resettable coverage or tracker document.
  Resets retire a generation so stale writers cannot restore cleared data.
- Store additive, non-idempotent documents as one `{meta, payload}` value. Metadata and
  payload must be written and reverted together so a stale write cannot preserve a
  contribution while erasing the watermark that prevents it from being counted again.
- Keep presence trackers as native Redis hashes where their `max(timestamp)` merge is
  idempotent. Cache-backed presence trackers use the document protocol.
- Give every writer a process-safe identity and ordered immutable deltas. Conflicts are
  detected through applied-sequence metadata and repaired on a later reporting cycle.
- Bound retained work by entry count, bytes, and age. Surface dropped or persistently
  unwritten work through storage health, logs, and the web report rather than silently
  presenting partial coverage as complete.
- Treat pointer initialization atomically and pointer loss as data loss. Cleanup of orphaned
  generations is best effort on cache backends; Redis also supports explicit orphan cleanup.
- Exclude Coverband's own storage I/O from query-burst tracking.
- Do not migrate pre-7.0 coverage or tracker data. Version the new format and start fresh.

## Release consequences

- `ActiveSupportCacheStore` supports Redis-backed Rails caches, Solid Cache, memcached, and
  file caches. Trackers work through the same adapter contract.
- The bespoke `MemcachedStore` was removed for 7.0; configure the same cache through
  `ActiveSupportCacheStore` instead.
- Redis remains the default store, but the `redis` gem is optional as of 7.0. Applications
  using the default must declare it themselves.
- The hosted coverband.io integration and `WebServiceStore` were removed because the service
  is no longer maintained.
- The cache adapter reports every 600 seconds by default. `HashRedisStore` remains preferable
  for large multi-process fleets because its per-file layout reduces write amplification.

## Guarantees verified by the conformance suite

- Concurrent additive reports converge without losing or double-counting contributions.
- Retry, same-writer conflicts, initialization races, resets, forks, and writer-identity
  changes preserve the sequencing invariant.
- A stale writer cannot undo a reset.
- Backend eviction, refused writes, retention-cap drops, and long outages are observable.
- Tracker clears and coverage resets are isolated by document.
- Lazy cache resolution fails explicitly and can recover on a later cycle.
- Coverband storage queries do not inflate query-burst results.

The protocol contract is shared by `RedisStore` and `ActiveSupportCacheStore` and exercised in
`test/coverband/storage/protocol_conformance_test.rb`. Backend integrations add Redis,
memcached, and Solid Cache coverage.

## Tradeoffs

- Whole-document cache writes amplify I/O and remain subject to backend value limits. In
  particular, memcached's default 1 MB value limit may reject a large coverage or tracker
  document. Coverband reports the unwritten state; operators must enable compression, raise
  the limit, or choose another backend.
- Cache backends without key enumeration cannot fully reclaim orphaned generations. Namespace
  expiry or a backend-specific clear is the full cleanup mechanism.
- Per-key clears on whole-document layouts are best effort if the initiating process exits
  before another reporting cycle observes the request.
- Cache eviction is detectable while a process retains protocol state, but eviction combined
  with a full application restart cannot always be distinguished from first use.

## Possible follow-up

A per-file cache layout, similar to `HashRedisStore` but without Lua, could reduce conflict
scope and write amplification. It is not required for the 7.0 storage contract.
