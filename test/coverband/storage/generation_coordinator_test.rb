# frozen_string_literal: true

require "test_helper"

class GenerationCoordinatorTest < Minitest::Test
  Result = Coverband::Storage::Generation::Result
  Change = Coverband::Storage::GenerationChange

  class FakeGeneration
    attr_reader :resolve_calls, :swept, :reset_token

    def initialize(*results)
      @results = results
      @resolve_calls = 0
    end

    def key
      "coordinator.pointer"
    end

    def resolve(primed: nil)
      @resolve_calls += 1
      @last_primed = primed
      result = @results.shift
      @last_result = result if result
      result || @last_result
    end

    attr_reader :last_primed

    def reset!(current_token:)
      @reset_token = current_token
      "reset-token"
    end

    def sweep(pointer)
      @swept = pointer
    end

    def retires?(pointer, token)
      Array(pointer[Coverband::Storage::Generation::RETIRE]).any? do |entry|
        entry[Coverband::Storage::Generation::TOKEN] == token
      end
    end
  end

  def test_nested_operations_resolve_once
    generation = FakeGeneration.new(result("one", initialized: true))
    coordinator = build_coordinator(generation)

    coordinator.operation do
      coordinator.operation { assert_equal "coordinator.gone", coordinator.data_key }
    end

    assert_equal 1, generation.resolve_calls
    assert_equal [Change::INITIALIZATION], changes.map(&:cause)
  end

  def test_primed_pointer_expires
    now = 10
    pointer = {"token" => "primed", "retire" => []}
    generation = FakeGeneration.new(result("fresh"))
    coordinator = build_coordinator(generation, clock: -> { now })
    coordinator.prime_pointer(pointer)
    now += Coverband::Storage::GenerationCoordinator::PRIMED_POINTER_TTL + 1

    coordinator.token

    assert_nil generation.last_primed
  end

  def test_reset_emits_a_typed_operator_reset
    generation = FakeGeneration.new(result("one"))
    coordinator = build_coordinator(generation)
    coordinator.token

    assert coordinator.reset

    change = changes.last
    assert_equal Change::OPERATOR_RESET, change.cause
    assert_equal "one", change.previous_token
    assert_equal "reset-token", change.authoritative_token
    assert_equal "one", generation.reset_token
  end

  def test_pointer_eviction_is_classified
    generation = FakeGeneration.new(
      result("one"),
      result("two", initialized: true, pointer_missing: true)
    )
    coordinator = build_coordinator(generation)
    coordinator.token
    coordinator.token

    assert_equal Change::POINTER_EVICTION, changes.last.cause
  end

  def test_matching_token_is_confirmed
    generation = FakeGeneration.new(result("one"), result("one"))
    coordinator = build_coordinator(generation)
    coordinator.token
    coordinator.token

    assert_equal Change::CONFIRMATION, changes.last.cause
    assert_equal "one", changes.last.previous_token
    assert_equal "one", changes.last.authoritative_token
  end

  def test_non_atomic_initialization_race_is_classified
    generation = FakeGeneration.new(
      result("loser", initialized: true),
      result("winner", pointer: {"token" => "winner", "retire" => []})
    )
    coordinator = build_coordinator(generation)
    coordinator.token
    coordinator.token

    assert_equal Change::INITIALIZATION_RACE, changes.last.cause
    assert_equal "loser", changes.last.previous_token
    assert_equal "winner", changes.last.authoritative_token
  end

  def test_retired_initialized_token_is_an_operator_reset
    pointer = {
      "token" => "winner",
      "retire" => [{"token" => "loser", "after" => Time.now.to_i}]
    }
    generation = FakeGeneration.new(
      result("loser", initialized: true),
      result("winner", pointer: pointer)
    )
    coordinator = build_coordinator(generation)
    coordinator.token
    coordinator.token

    assert_equal Change::OPERATOR_RESET, changes.last.cause
  end

  def test_delayed_sweep_runs_after_outermost_operation
    pointer = {"token" => "one", "retire" => [{"token" => "old", "after" => 1}]}
    generation = FakeGeneration.new(result("one", pointer: pointer))
    coordinator = build_coordinator(generation)

    coordinator.operation do
      coordinator.operation { assert_nil generation.swept }
    end

    assert_equal pointer, generation.swept
  end

  private

  attr_reader :changes

  def build_coordinator(generation, clock: -> { Time.now.to_i })
    @changes = []
    Coverband::Storage::GenerationCoordinator.new(
      target: Object.new,
      key_base: "coordinator",
      grace_seconds: 10,
      generation: generation,
      clock: clock,
      on_change: ->(change) { @changes << change }
    )
  end

  def result(token, initialized: false, pointer: nil, pointer_missing: false)
    pointer ||= {"token" => token, "retire" => []}
    Result.new(
      token: token,
      initialized: initialized,
      pointer: pointer,
      pointer_missing: pointer_missing
    )
  end
end
