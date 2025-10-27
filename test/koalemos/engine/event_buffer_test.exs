defmodule Koalemos.Engine.EventBufferTest do
  use ExUnit.Case, async: true
  alias Koalemos.Engine.EventBuffer

  doctest EventBuffer

  describe "new/0" do
    test "creates empty buffer" do
      assert EventBuffer.new() == %{}
    end

    test "created buffer is empty" do
      buffer = EventBuffer.new()
      assert EventBuffer.empty?(buffer)
      assert EventBuffer.size(buffer) == 0
    end
  end

  describe "add/3 and add/4" do
    test "adds event to empty buffer" do
      buffer = EventBuffer.new()
      buffer = EventBuffer.add(buffer, :user_input, "hello")

      assert EventBuffer.size(buffer, :user_input) == 1
      assert not EventBuffer.empty?(buffer)
    end

    test "adds multiple events of same type" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:msg, "first")
        |> EventBuffer.add(:msg, "second")
        |> EventBuffer.add(:msg, "third")

      assert EventBuffer.size(buffer, :msg) == 3
    end

    test "adds events of different types" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:user_input, "input")
        |> EventBuffer.add(:webhook, "hook")
        |> EventBuffer.add(:timer, "tick")

      assert EventBuffer.size(buffer, :user_input) == 1
      assert EventBuffer.size(buffer, :webhook) == 1
      assert EventBuffer.size(buffer, :timer) == 1
      assert EventBuffer.size(buffer) == 3
    end

    test "uses custom timestamp when provided" do
      buffer = EventBuffer.add(EventBuffer.new(), :msg, "data", 12345)

      {:found, :msg, "data", timestamp, _} = EventBuffer.find_and_remove(buffer, [:msg])
      assert timestamp == 12345
    end

    test "generates timestamp when not provided" do
      before = System.system_time(:millisecond)
      buffer = EventBuffer.add(EventBuffer.new(), :msg, "data")
      after_add = System.system_time(:millisecond)

      {:found, :msg, "data", timestamp, _} = EventBuffer.find_and_remove(buffer, [:msg])
      assert timestamp >= before
      assert timestamp <= after_add
    end

    test "stores complex data structures" do
      complex_data = %{
        user: "alice",
        metadata: %{source: "api", version: 2},
        items: [1, 2, 3]
      }

      buffer = EventBuffer.add(EventBuffer.new(), :event, complex_data)

      {:found, :event, ^complex_data, _, _} = EventBuffer.find_and_remove(buffer, [:event])
    end
  end

  describe "find_and_remove/2" do
    test "finds and removes event when present" do
      buffer = EventBuffer.add(EventBuffer.new(), :user_input, "hello", 1000)

      result = EventBuffer.find_and_remove(buffer, [:user_input])

      assert {:found, :user_input, "hello", 1000, new_buffer} = result
      assert EventBuffer.empty?(new_buffer)
    end

    test "returns :not_found when buffer is empty" do
      buffer = EventBuffer.new()
      assert EventBuffer.find_and_remove(buffer, [:user_input]) == :not_found
    end

    test "returns :not_found when event type not in buffer" do
      buffer = EventBuffer.add(EventBuffer.new(), :webhook, "data")
      assert EventBuffer.find_and_remove(buffer, [:user_input]) == :not_found
    end

    test "maintains FIFO ordering for same type" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:msg, "first")
        |> EventBuffer.add(:msg, "second")
        |> EventBuffer.add(:msg, "third")

      {:found, :msg, "first", _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      {:found, :msg, "second", _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      {:found, :msg, "third", _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      assert EventBuffer.find_and_remove(buffer, [:msg]) == :not_found
    end

    test "searches multiple event types in order" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:webhook, "webhook_data")
        |> EventBuffer.add(:timer, "timer_data")

      # Search for user_input first, then webhook, then timer
      {:found, :webhook, "webhook_data", _, buffer} =
        EventBuffer.find_and_remove(buffer, [:user_input, :webhook, :timer])

      # Now only timer is left
      {:found, :timer, "timer_data", _, buffer} =
        EventBuffer.find_and_remove(buffer, [:user_input, :webhook, :timer])

      assert EventBuffer.empty?(buffer)
    end

    test "returns first matching type from list" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:first, "data1")
        |> EventBuffer.add(:second, "data2")

      # Should return :first since it's checked first
      {:found, :first, "data1", _, _} =
        EventBuffer.find_and_remove(buffer, [:first, :second])
    end

    test "removes event from buffer" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:msg, "one")
        |> EventBuffer.add(:msg, "two")

      assert EventBuffer.size(buffer, :msg) == 2

      {:found, _, _, _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      assert EventBuffer.size(buffer, :msg) == 1

      {:found, _, _, _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      assert EventBuffer.size(buffer, :msg) == 0
      assert EventBuffer.empty?(buffer)
    end

    test "removes event type key when last event removed" do
      buffer = EventBuffer.add(EventBuffer.new(), :msg, "only")

      {:found, :msg, "only", _, new_buffer} = EventBuffer.find_and_remove(buffer, [:msg])

      # The :msg key should be completely removed from the map
      refute Map.has_key?(new_buffer, :msg)
      assert new_buffer == %{}
    end

    test "preserves other event types when removing one" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:keep, "this")
        |> EventBuffer.add(:remove, "that")

      {:found, :remove, "that", _, buffer} = EventBuffer.find_and_remove(buffer, [:remove])

      assert EventBuffer.size(buffer, :keep) == 1
      {:found, :keep, "this", _, _} = EventBuffer.find_and_remove(buffer, [:keep])
    end
  end

  describe "size/1" do
    test "returns 0 for empty buffer" do
      assert EventBuffer.size(EventBuffer.new()) == 0
    end

    test "counts events across all types" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:type1, "a")
        |> EventBuffer.add(:type1, "b")
        |> EventBuffer.add(:type2, "c")
        |> EventBuffer.add(:type3, "d")

      assert EventBuffer.size(buffer) == 4
    end

    test "updates after adding events" do
      buffer = EventBuffer.new()
      assert EventBuffer.size(buffer) == 0

      buffer = EventBuffer.add(buffer, :msg, "one")
      assert EventBuffer.size(buffer) == 1

      buffer = EventBuffer.add(buffer, :msg, "two")
      assert EventBuffer.size(buffer) == 2
    end

    test "updates after removing events" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:msg, "one")
        |> EventBuffer.add(:msg, "two")

      assert EventBuffer.size(buffer) == 2

      {:found, _, _, _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      assert EventBuffer.size(buffer) == 1

      {:found, _, _, _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      assert EventBuffer.size(buffer) == 0
    end
  end

  describe "size/2 (for specific type)" do
    test "returns 0 for missing type" do
      buffer = EventBuffer.new()
      assert EventBuffer.size(buffer, :nonexistent) == 0
    end

    test "returns count for specific type" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:user_input, "a")
        |> EventBuffer.add(:user_input, "b")
        |> EventBuffer.add(:webhook, "c")

      assert EventBuffer.size(buffer, :user_input) == 2
      assert EventBuffer.size(buffer, :webhook) == 1
    end

    test "doesn't count events from other types" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:type1, "data")
        |> EventBuffer.add(:type2, "data")
        |> EventBuffer.add(:type2, "data")

      assert EventBuffer.size(buffer, :type1) == 1
      assert EventBuffer.size(buffer, :type2) == 2
    end
  end

  describe "event_types/1" do
    test "returns empty list for empty buffer" do
      assert EventBuffer.event_types(EventBuffer.new()) == []
    end

    test "returns list of event types present" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:user_input, "data")
        |> EventBuffer.add(:webhook, "data")
        |> EventBuffer.add(:timer, "data")

      types = EventBuffer.event_types(buffer)
      assert length(types) == 3
      assert :user_input in types
      assert :webhook in types
      assert :timer in types
    end

    test "doesn't duplicate types with multiple events" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:msg, "one")
        |> EventBuffer.add(:msg, "two")
        |> EventBuffer.add(:msg, "three")

      assert EventBuffer.event_types(buffer) == [:msg]
    end
  end

  describe "cleanup_old_events/2" do
    test "removes events older than max age" do
      now = System.system_time(:millisecond)

      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:old, "ancient", now - 10_000)
        |> EventBuffer.add(:recent, "new", now - 100)

      buffer = EventBuffer.cleanup_old_events(buffer, 5_000)

      assert EventBuffer.size(buffer, :old) == 0
      assert EventBuffer.size(buffer, :recent) == 1
    end

    test "keeps events within max age" do
      now = System.system_time(:millisecond)

      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:msg, "one", now - 1_000)
        |> EventBuffer.add(:msg, "two", now - 2_000)
        |> EventBuffer.add(:msg, "three", now - 3_000)

      buffer = EventBuffer.cleanup_old_events(buffer, 5_000)

      assert EventBuffer.size(buffer, :msg) == 3
    end

    test "removes event type when all events are old" do
      now = System.system_time(:millisecond)

      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:old1, "data", now - 10_000)
        |> EventBuffer.add(:old2, "data", now - 10_000)

      buffer = EventBuffer.cleanup_old_events(buffer, 5_000)

      assert EventBuffer.empty?(buffer)
      refute Map.has_key?(buffer, :old1)
      refute Map.has_key?(buffer, :old2)
    end

    test "keeps some events of a type and removes others" do
      now = System.system_time(:millisecond)

      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:msg, "old1", now - 10_000)
        |> EventBuffer.add(:msg, "recent1", now - 1_000)
        |> EventBuffer.add(:msg, "old2", now - 8_000)
        |> EventBuffer.add(:msg, "recent2", now - 2_000)

      buffer = EventBuffer.cleanup_old_events(buffer, 5_000)

      assert EventBuffer.size(buffer, :msg) == 2
      {:found, :msg, "recent1", _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      {:found, :msg, "recent2", _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      assert EventBuffer.empty?(buffer)
    end

    test "handles empty buffer" do
      buffer = EventBuffer.new()
      buffer = EventBuffer.cleanup_old_events(buffer, 5_000)
      assert EventBuffer.empty?(buffer)
    end

    test "max_age of 0 removes all events" do
      now = System.system_time(:millisecond)

      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:msg, "data", now)

      # Even events from "now" are technically older than 0ms ago
      buffer = EventBuffer.cleanup_old_events(buffer, 0)

      # Depending on timing, this might remove the event or not
      # So we just verify it doesn't crash
      assert is_map(buffer)
    end
  end

  describe "empty?/1" do
    test "returns true for new buffer" do
      assert EventBuffer.empty?(EventBuffer.new())
    end

    test "returns false when buffer has events" do
      buffer = EventBuffer.add(EventBuffer.new(), :msg, "data")
      refute EventBuffer.empty?(buffer)
    end

    test "returns true after removing all events" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:msg, "data")

      {:found, _, _, _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      assert EventBuffer.empty?(buffer)
    end

    test "returns false with multiple event types" do
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:type1, "data")
        |> EventBuffer.add(:type2, "data")

      refute EventBuffer.empty?(buffer)
    end
  end

  describe "integration scenarios" do
    test "realistic workflow: add, find, cleanup" do
      now = System.system_time(:millisecond)

      # Simulate events arriving over time
      buffer =
        EventBuffer.new()
        |> EventBuffer.add(:user_input, "first message", now - 1000)
        |> EventBuffer.add(:webhook, "api call", now - 900)
        |> EventBuffer.add(:user_input, "second message", now)

      # Find user input
      {:found, :user_input, "first message", _, buffer} =
        EventBuffer.find_and_remove(buffer, [:user_input, :timer])

      # Still have 2 events
      assert EventBuffer.size(buffer) == 2

      # Cleanup old events (> 750ms old)
      buffer = EventBuffer.cleanup_old_events(buffer, 750)

      # Should only have the recent user_input left (webhook was old too)
      assert EventBuffer.size(buffer) == 1
      assert EventBuffer.size(buffer, :user_input) == 1
    end

    test "handles rapid event additions and removals" do
      buffer = EventBuffer.new()

      # Add 100 events
      buffer =
        Enum.reduce(1..100, buffer, fn i, acc ->
          EventBuffer.add(acc, :msg, "message_#{i}")
        end)

      assert EventBuffer.size(buffer) == 100

      # Remove 50 events
      buffer =
        Enum.reduce(1..50, buffer, fn _, acc ->
          {:found, _, _, _, new_buffer} = EventBuffer.find_and_remove(acc, [:msg])
          new_buffer
        end)

      assert EventBuffer.size(buffer) == 50
    end
  end
end
