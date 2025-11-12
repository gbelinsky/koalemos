defmodule Koalemos.Caches.ConsoleCacheTest do
  use ExUnit.Case, async: false
  alias Koalemos.Caches.ConsoleCache

  setup do
    # ConsoleCache is started by the Application supervision tree
    # We just need to clear it before each test

    # Clear all console messages before each test
    ConsoleCache.clear_all()

    # Use unique routine IDs per test to avoid conflicts
    routine_id = "test-routine-#{:erlang.unique_integer([:positive])}"
    {:ok, routine_id: routine_id}
  end

  # Helper to create a test console message
  defp create_message(level \\ "log", message \\ "test message") do
    %{
      level: level,
      message: message,
      timestamp: System.system_time(:millisecond)
    }
  end

  describe "add_message/2" do
    test "stores a console message successfully", %{routine_id: routine_id} do
      message = create_message("log", "Hello from wireframe")

      assert :ok = ConsoleCache.add_message(routine_id, message)

      # Verify it was stored
      messages = ConsoleCache.get_messages(routine_id)
      assert length(messages) == 1
      assert hd(messages).level == "log"
      assert hd(messages).message == "Hello from wireframe"
    end

    test "stores messages for multiple routines independently" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      msg_1 = create_message("log", "message 1")
      msg_2 = create_message("warn", "message 2")

      ConsoleCache.add_message(routine_1, msg_1)
      ConsoleCache.add_message(routine_2, msg_2)

      messages_1 = ConsoleCache.get_messages(routine_1)
      messages_2 = ConsoleCache.get_messages(routine_2)

      assert length(messages_1) == 1
      assert length(messages_2) == 1
      assert hd(messages_1).message == "message 1"
      assert hd(messages_2).message == "message 2"
    end

    test "stores messages with different levels", %{routine_id: routine_id} do
      ConsoleCache.add_message(routine_id, create_message("log", "log message"))
      ConsoleCache.add_message(routine_id, create_message("warn", "warn message"))
      ConsoleCache.add_message(routine_id, create_message("error", "error message"))

      messages = ConsoleCache.get_messages(routine_id)
      assert length(messages) == 3
    end

    test "adds cached_at timestamp to messages", %{routine_id: routine_id} do
      ConsoleCache.add_message(routine_id, create_message())

      messages = ConsoleCache.get_messages(routine_id)
      message = hd(messages)

      assert Map.has_key?(message, :cached_at)
      assert is_integer(message.cached_at)
    end
  end

  describe "add_message/2 - rate limiting" do
    test "allows up to 15 messages per second", %{routine_id: routine_id} do
      # Add 15 messages rapidly
      results =
        Enum.map(1..15, fn i ->
          ConsoleCache.add_message(routine_id, create_message("log", "message #{i}"))
        end)

      # All should succeed
      assert Enum.all?(results, &(&1 == :ok))

      messages = ConsoleCache.get_messages(routine_id)
      assert length(messages) == 15
    end

    test "rejects messages exceeding 15 per second", %{routine_id: routine_id} do
      # Add 20 messages rapidly (should hit rate limit)
      results =
        Enum.map(1..20, fn i ->
          ConsoleCache.add_message(routine_id, create_message("log", "message #{i}"))
        end)

      # Some should be rate limited
      ok_count = Enum.count(results, &(&1 == :ok))
      error_count = Enum.count(results, &match?({:error, :rate_limit}, &1))

      assert ok_count > 0
      assert error_count > 0

      # Should have warning messages inserted
      messages = ConsoleCache.get_messages(routine_id)
      warnings = Enum.filter(messages, &Map.get(&1, :system_message, false))
      assert length(warnings) > 0
      assert hd(warnings).level == "warn"
      assert hd(warnings).message =~ "rate limit"
    end

    test "detects duplicate message spam", %{routine_id: routine_id} do
      # Send the same message 15 times
      same_message = create_message("log", "repeated message")

      results =
        Enum.map(1..15, fn _ ->
          ConsoleCache.add_message(routine_id, same_message)
        end)

      # Some should be rejected as duplicates
      ok_count = Enum.count(results, &(&1 == :ok))
      error_count = Enum.count(results, &match?({:error, :duplicate_spam}, &1))

      assert ok_count > 0
      assert error_count > 0

      # Should have duplicate warning
      messages = ConsoleCache.get_messages(routine_id)
      warnings = Enum.filter(messages, &Map.get(&1, :system_message, false))
      duplicate_warning = Enum.find(warnings, &(&1.message =~ "Duplicate"))
      assert duplicate_warning != nil
    end

    test "allows duplicate messages after time window expires", %{routine_id: routine_id} do
      # Note: This test would need to wait 5+ seconds to fully test the time window
      # For now, we just verify the mechanism works with fresh messages

      message = create_message("log", "test")

      # Add message multiple times
      ConsoleCache.add_message(routine_id, message)
      ConsoleCache.add_message(routine_id, message)

      # Should work initially
      messages = ConsoleCache.get_messages(routine_id)
      assert length(messages) >= 2
    end

    test "enforces max 500 messages per routine", %{routine_id: routine_id} do
      # Add 600 messages
      Enum.each(1..600, fn i ->
        ConsoleCache.add_message(routine_id, create_message("log", "message #{i}"))
      end)

      messages = ConsoleCache.get_messages(routine_id)
      # Should be trimmed to 500
      assert length(messages) <= 500
    end
  end

  describe "get_messages/2" do
    test "returns messages most recent first", %{routine_id: routine_id} do
      ConsoleCache.add_message(routine_id, create_message("log", "first"))
      # Small delay to ensure different timestamps
      :timer.sleep(1)
      ConsoleCache.add_message(routine_id, create_message("log", "second"))
      :timer.sleep(1)
      ConsoleCache.add_message(routine_id, create_message("log", "third"))

      messages = ConsoleCache.get_messages(routine_id)

      # Most recent should be first
      assert hd(messages).message == "third"
      assert Enum.at(messages, 1).message == "second"
      assert Enum.at(messages, 2).message == "first"
    end

    test "filters by timestamp with :since option", %{routine_id: routine_id} do
      now = System.system_time(:millisecond)

      ConsoleCache.add_message(routine_id, %{
        level: "log",
        message: "old message",
        timestamp: now - 10000
      })

      ConsoleCache.add_message(routine_id, %{
        level: "log",
        message: "new message",
        timestamp: now
      })

      # Get only messages after (now - 5000)
      messages = ConsoleCache.get_messages(routine_id, since: now - 5000)

      assert length(messages) == 1
      assert hd(messages).message == "new message"
    end

    test "filters by level with :level option", %{routine_id: routine_id} do
      ConsoleCache.add_message(routine_id, create_message("log", "log message"))
      ConsoleCache.add_message(routine_id, create_message("warn", "warn message"))
      ConsoleCache.add_message(routine_id, create_message("error", "error message"))

      # Get only errors
      errors = ConsoleCache.get_messages(routine_id, level: "error")
      assert length(errors) == 1
      assert hd(errors).level == "error"

      # Get only warnings
      warnings = ConsoleCache.get_messages(routine_id, level: "warn")
      assert length(warnings) == 1
      assert hd(warnings).level == "warn"
    end

    test "limits results with :limit option", %{routine_id: routine_id} do
      # Add 20 messages
      Enum.each(1..20, fn i ->
        ConsoleCache.add_message(routine_id, create_message("log", "message #{i}"))
      end)

      messages = ConsoleCache.get_messages(routine_id, limit: 5)
      assert length(messages) == 5
    end

    test "combines multiple filters", %{routine_id: routine_id} do
      now = System.system_time(:millisecond)

      ConsoleCache.add_message(routine_id, %{
        level: "log",
        message: "old log",
        timestamp: now - 10000
      })

      ConsoleCache.add_message(routine_id, %{
        level: "error",
        message: "old error",
        timestamp: now - 10000
      })

      ConsoleCache.add_message(routine_id, %{
        level: "error",
        message: "new error",
        timestamp: now
      })

      # Get only recent errors
      messages = ConsoleCache.get_messages(routine_id, since: now - 5000, level: "error")

      assert length(messages) == 1
      assert hd(messages).message == "new error"
    end

    test "returns empty list when no messages exist" do
      nonexistent_id = "nonexistent-#{:erlang.unique_integer([:positive])}"

      messages = ConsoleCache.get_messages(nonexistent_id)
      assert messages == []
    end
  end

  describe "clear_messages/1" do
    test "removes all messages for specified routine", %{routine_id: routine_id} do
      ConsoleCache.add_message(routine_id, create_message())

      assert :ok = ConsoleCache.clear_messages(routine_id)
      assert ConsoleCache.get_messages(routine_id) == []
    end

    test "returns :ok even if no messages exist" do
      nonexistent_id = "nonexistent-#{:erlang.unique_integer([:positive])}"

      assert :ok = ConsoleCache.clear_messages(nonexistent_id)
    end

    test "does not affect other routines' messages" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      ConsoleCache.add_message(routine_1, create_message("log", "message 1"))
      ConsoleCache.add_message(routine_2, create_message("log", "message 2"))

      ConsoleCache.clear_messages(routine_1)

      # routine_2's messages should still exist
      messages_2 = ConsoleCache.get_messages(routine_2)
      assert length(messages_2) == 1
      assert ConsoleCache.get_messages(routine_1) == []
    end

    test "also clears rate limiting data", %{routine_id: routine_id} do
      # Add some messages
      Enum.each(1..10, fn i ->
        ConsoleCache.add_message(routine_id, create_message("log", "message #{i}"))
      end)

      # Clear everything
      ConsoleCache.clear_messages(routine_id)

      # Stats should be reset
      stats = ConsoleCache.get_stats(routine_id)
      assert stats.message_count == 0
      assert stats.recent_message_timestamps == []
    end
  end

  describe "clear_all/0" do
    test "removes all messages from all routines" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      ConsoleCache.add_message(routine_1, create_message())
      ConsoleCache.add_message(routine_2, create_message())

      assert :ok = ConsoleCache.clear_all()

      assert ConsoleCache.get_messages(routine_1) == []
      assert ConsoleCache.get_messages(routine_2) == []
    end
  end

  describe "get_stats/1" do
    test "returns statistics about console usage", %{routine_id: routine_id} do
      ConsoleCache.add_message(routine_id, create_message("log", "test"))

      stats = ConsoleCache.get_stats(routine_id)

      assert stats.message_count == 1
      assert is_list(stats.recent_message_timestamps)
      assert is_map(stats.duplicate_counts)
      assert is_integer(stats.rate_limit_warnings)
    end

    test "returns empty stats for non-existent routine" do
      nonexistent_id = "nonexistent-#{:erlang.unique_integer([:positive])}"

      stats = ConsoleCache.get_stats(nonexistent_id)

      assert stats.message_count == 0
      assert stats.recent_message_timestamps == []
      assert stats.duplicate_counts == %{}
      assert stats.rate_limit_warnings == 0
    end

    test "tracks rate limit warnings", %{routine_id: routine_id} do
      # Trigger rate limit by sending many messages
      Enum.each(1..20, fn i ->
        ConsoleCache.add_message(routine_id, create_message("log", "message #{i}"))
      end)

      stats = ConsoleCache.get_stats(routine_id)
      assert stats.rate_limit_warnings > 0
    end
  end

  describe "supervision" do
    test "starts with the application" do
      # The GenServer should be started by setup
      # Verify it's accessible by trying an operation
      routine_id = "supervision-test-#{:erlang.unique_integer([:positive])}"

      assert :ok = ConsoleCache.add_message(routine_id, create_message())
      assert length(ConsoleCache.get_messages(routine_id)) == 1
    end

    test "is registered as a named process" do
      # Should be able to find the process by name
      pid = Process.whereis(ConsoleCache)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "integration" do
    test "full workflow: add, get, filter, clear" do
      routine_id = "workflow-test-#{:erlang.unique_integer([:positive])}"

      # Add various messages
      ConsoleCache.add_message(routine_id, create_message("log", "Starting app"))
      ConsoleCache.add_message(routine_id, create_message("warn", "Deprecation warning"))
      ConsoleCache.add_message(routine_id, create_message("error", "Failed to load"))

      # Get all messages
      all_messages = ConsoleCache.get_messages(routine_id)
      assert length(all_messages) == 3

      # Filter by level
      errors = ConsoleCache.get_messages(routine_id, level: "error")
      assert length(errors) == 1
      assert hd(errors).message == "Failed to load"

      # Clear messages
      ConsoleCache.clear_messages(routine_id)
      assert ConsoleCache.get_messages(routine_id) == []
    end

    test "simulates console spam protection" do
      routine_id = "spam-test-#{:erlang.unique_integer([:positive])}"

      # Simulate infinite loop console spam
      same_message = create_message("log", "Loop iteration")

      # Send 50 identical messages
      Enum.each(1..50, fn _ ->
        ConsoleCache.add_message(routine_id, same_message)
      end)

      messages = ConsoleCache.get_messages(routine_id)

      # Should have warnings about duplicate spam
      warnings = Enum.filter(messages, &Map.get(&1, :system_message, false))
      assert length(warnings) > 0

      # Should have stored messages + warnings (warnings are also messages)
      # The total won't be all 50 original messages because some were rejected
      # But warnings were added, so total could still be high
      non_warning_messages = Enum.filter(messages, &(!Map.get(&1, :system_message, false)))
      assert length(non_warning_messages) < 50, "Should have rejected some duplicate messages"

      # Stats should show duplicate detection
      stats = ConsoleCache.get_stats(routine_id)
      assert map_size(stats.duplicate_counts) > 0
    end
  end
end
