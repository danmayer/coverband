# frozen_string_literal: true

require "json"
require "securerandom"

module Coverband
  module Storage
    ###
    # Per document generation pointer holding an opaque token.
    #
    # The token lives in the key rather than in the document because a stale
    # writer can overwrite a value but can't overwrite a key it no longer
    # addresses. That is what makes reset strong on a last write wins store
    # without CAS: a reset retires the whole key, and stragglers write to a key
    # nothing reads.
    #
    # Reporters may initialize an absent pointer. Only reset replaces one that
    # exists; a reporter re-asserting a token it read earlier would be
    # indistinguishable from resurrecting a generation retired in between.
    ###
    class Generation
      TOKEN = "token"
      RETIRE = "retire"
      AFTER = "after"
      RETIRE_LIMIT = 8
      SWEEP_WINDOW = 24 * 60 * 60
      GRACE = 2

      # pointer rides along so callers can run the sweep without reading again
      Result = Struct.new(:token, :initialized, :pointer, keyword_init: true)

      def initialize(target, key, grace_seconds:)
        @target = target
        @key = key
        @grace_seconds = grace_seconds
      end

      attr_reader :key

      def read
        parse(@target.read(@key))
      end

      ###
      # Returns the authoritative token, creating one when the pointer is
      # absent. `initialized` tells the caller it created the pointer, which is
      # what separates "I lost an init race" from "an operator reset" later on.
      ###
      def resolve
        raw = @target.read(@key)
        pointer = parse(raw)
        if pointer && pointer[TOKEN]
          return Result.new(token: pointer[TOKEN], initialized: false, pointer: pointer)
        end

        token = SecureRandom.hex(8)
        @target.create(@key, {TOKEN => token, RETIRE => []}.to_json)

        # another process may have won an atomic create
        settled = parse(@target.read(@key))
        actual = (settled && settled[TOKEN]) ? settled[TOKEN] : token
        Result.new(token: actual, initialized: true, pointer: settled)
      end

      ###
      # Writes a fresh token without reading it first, so concurrent resets
      # collapse harmlessly: every one of them is a valid reset.
      #
      # Appending to the cleanup queue does need the old pointer, which is why
      # the queue is best effort. Two concurrent resets can drop one another's
      # cleanup instruction. Reset itself stays correct; only cleanup suffers.
      ###
      def reset!(current_token: nil)
        previous = parse(@target.read(@key))
        retired = previous ? Array(previous[RETIRE]) : []
        old_token = current_token || previous&.fetch(TOKEN, nil)

        if old_token
          retired << {TOKEN => old_token, AFTER => Time.now.to_i + @grace_seconds}
        end
        retired = prune_retired(retired).last(RETIRE_LIMIT)

        token = SecureRandom.hex(8)
        written = @target.write(@key, {TOKEN => token, RETIRE => retired}.to_json)

        # a pointer write that didn't land is a reset that didn't happen
        return nil unless written

        @target.delete(data_key_for(old_token)) if old_token
        token
      end

      ###
      # Any reporter can run the delayed sweep, because the reset initiator is
      # often a web request or rake task that has already exited. Deletes are
      # idempotent, and the window stops them repeating forever. No reporter
      # writes the pointer.
      ###
      def sweep(pointer = nil)
        pointer ||= parse(@target.read(@key))
        return unless pointer

        now = Time.now.to_i
        Array(pointer[RETIRE]).each do |entry|
          after = entry[AFTER].to_i
          next unless now > after && now < (after + SWEEP_WINDOW)

          @target.delete(data_key_for(entry[TOKEN]))
        end
      end

      ###
      # Whether this pointer says the token was retired by a reset. That is what
      # separates "an operator cleared this" from "we lost an initialization
      # race", which want opposite handling of unconfirmed work.
      ###
      def retires?(pointer, token)
        return false unless pointer && token

        Array(pointer[RETIRE]).any? { |entry| entry[TOKEN] == token }
      end

      def data_key_for(token)
        "#{@key.sub(/\.pointer\z/, "")}.g#{token}"
      end

      private

      def prune_retired(entries)
        cutoff = Time.now.to_i - SWEEP_WINDOW
        entries.select { |entry| entry[AFTER].to_i > cutoff }
      end

      def parse(raw)
        return nil if raw.nil?

        parsed = raw.is_a?(String) ? JSON.parse(raw) : raw
        parsed.is_a?(Hash) ? parsed : nil
      rescue JSON::ParserError
        nil
      end
    end
  end
end
