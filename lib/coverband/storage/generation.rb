# frozen_string_literal: true

require "json"
require "securerandom"

module Coverband
  module Storage
    ###
    # Per document generation pointer holding an opaque token.
    #
    # The token lives in the key, not the document, because a stale writer can
    # overwrite a value but not a key it no longer addresses. That is what makes
    # reset strong on a last-write-wins store without CAS: a reset retires the
    # whole key and stragglers write where nothing reads.
    #
    # Reporters may initialize an absent pointer, but only reset replaces one
    # that exists: a reporter re-asserting a token it read earlier would be
    # indistinguishable from resurrecting a generation retired in between.
    ###
    class Generation
      TOKEN = "token"
      RETIRE = "retire"
      AFTER = "after"
      RETIRE_LIMIT = 8
      SWEEP_WINDOW = 24 * 60 * 60
      GRACE = 2

      ###
      # pointer rides along so callers can sweep without reading again.
      # pointer_missing separates "nobody has written this yet" from "the pointer
      # we were using is gone" -- the second orphans a document that may still
      # exist, which is loss worth reporting.
      ###
      Result = Struct.new(:token, :initialized, :pointer, :pointer_missing, keyword_init: true)

      def initialize(target, key, grace_seconds:)
        @target = target
        # frozen because it is a Hash key when pointer reads are batched: an
        # unfrozen String key makes Ruby allocate a frozen duplicate, which newer
        # versions intern globally and never release
        @key = key.dup.freeze
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
      #
      # `primed` is a pointer value the caller already fetched, so a reporting
      # cycle can read every document's pointer in one round trip.
      ###
      def resolve(primed: nil)
        return resolve_from(primed) if primed.is_a?(Hash)

        raw = primed.nil? ? @target.read(@key) : primed
        pointer = parse(raw)
        if pointer && pointer[TOKEN]
          return Result.new(token: pointer[TOKEN], initialized: false, pointer: pointer, pointer_missing: false)
        end

        token = SecureRandom.hex(8)
        @target.create(@key, {TOKEN => token, RETIRE => []}.to_json)

        # another process may have won an atomic create
        settled = parse(@target.read(@key))
        actual = (settled && settled[TOKEN]) ? settled[TOKEN] : token
        Result.new(token: actual, initialized: true, pointer: settled, pointer_missing: true)
      end

      ###
      # Writes a fresh token without reading first, so concurrent resets collapse
      # harmlessly: every one of them is a valid reset. Appending to the cleanup
      # queue does need the old pointer, so that queue is best effort -- two
      # concurrent resets can drop one another's instruction. Only cleanup
      # suffers; reset itself stays correct.
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
        # never expires: a pointer outliving its document would leave the
        # documents it names unreachable while still being written
        written = @target.write(@key, {TOKEN => token, RETIRE => retired}.to_json, expires_in: nil)

        # a pointer write that didn't land is a reset that didn't happen
        return nil unless written

        @target.delete(data_key_for(old_token)) if old_token
        token
      end

      ###
      # Any reporter runs the delayed sweep, because the reset initiator is often
      # a web request or rake task that has already exited. Deletes are
      # idempotent and the window stops them repeating forever; no reporter
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

      # whether the pointer says a reset retired this token, which is what
      # separates an operator clear from a lost initialization race

      def retires?(pointer, token)
        return false unless pointer && token

        Array(pointer[RETIRE]).any? { |entry| entry[TOKEN] == token }
      end

      private

      # a pointer already parsed by a batched read; priming the parsed value
      # rather than the raw string keeps that read's strings from being
      # referenced past the batch itself
      def resolve_from(pointer)
        if pointer[TOKEN]
          Result.new(token: pointer[TOKEN], initialized: false, pointer: pointer, pointer_missing: false)
        else
          resolve
        end
      end

      def data_key_for(token)
        "#{@key.sub(/\.pointer\z/, "")}.g#{token}"
      end

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
