defmodule Koalemos.Caches.VariableStateCacheTest do
  use ExUnit.Case, async: false
  alias Koalemos.Caches.VariableStateCache

  setup do
    # VariableStateCache is started by the Application supervision tree
    # We just need to clear it before each test

    # Clear all variable states before each test
    VariableStateCache.clear_all()

    # Use unique routine IDs per test to avoid conflicts
    routine_id = "test-routine-#{:erlang.unique_integer([:positive])}"
    {:ok, routine_id: routine_id}
  end

  describe "add_variable_state/2" do
    test "stores variable state successfully", %{routine_id: routine_id} do
      variables = %{"count" => 42, "name" => "Alice"}

      assert :ok = VariableStateCache.add_variable_state(routine_id, variables)

      # Verify it was stored
      assert ^variables = VariableStateCache.get_variable_state(routine_id)
    end

    test "overwrites existing variable state for same routine", %{routine_id: routine_id} do
      first_vars = %{"x" => 1}
      second_vars = %{"x" => 2, "y" => 3}

      VariableStateCache.add_variable_state(routine_id, first_vars)
      VariableStateCache.add_variable_state(routine_id, second_vars)

      # Should have the second variable state
      assert ^second_vars = VariableStateCache.get_variable_state(routine_id)
    end

    test "stores variable states for multiple routines independently" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      vars_1 = %{"a" => 1}
      vars_2 = %{"b" => 2}

      VariableStateCache.add_variable_state(routine_1, vars_1)
      VariableStateCache.add_variable_state(routine_2, vars_2)

      assert ^vars_1 = VariableStateCache.get_variable_state(routine_1)
      assert ^vars_2 = VariableStateCache.get_variable_state(routine_2)
    end

    test "handles empty variable map", %{routine_id: routine_id} do
      variables = %{}

      assert :ok = VariableStateCache.add_variable_state(routine_id, variables)
      assert %{} = VariableStateCache.get_variable_state(routine_id)
    end

    test "handles various value types", %{routine_id: routine_id} do
      variables = %{
        "number" => 123,
        "string" => "hello",
        "boolean" => true,
        "list" => [1, 2, 3],
        "map" => %{"nested" => "value"},
        "nil" => nil
      }

      VariableStateCache.add_variable_state(routine_id, variables)

      stored = VariableStateCache.get_variable_state(routine_id)
      assert stored["number"] == 123
      assert stored["string"] == "hello"
      assert stored["boolean"] == true
      assert stored["list"] == [1, 2, 3]
      assert stored["map"] == %{"nested" => "value"}
      assert stored["nil"] == nil
    end
  end

  describe "get_variable_state/1" do
    test "returns variables when state exists", %{routine_id: routine_id} do
      variables = %{"test" => "value"}
      VariableStateCache.add_variable_state(routine_id, variables)

      assert ^variables = VariableStateCache.get_variable_state(routine_id)
    end

    test "returns nil when state does not exist" do
      nonexistent_id = "nonexistent-routine-#{:erlang.unique_integer([:positive])}"

      assert VariableStateCache.get_variable_state(nonexistent_id) == nil
    end

    test "returns nil after state is cleared", %{routine_id: routine_id} do
      VariableStateCache.add_variable_state(routine_id, %{"x" => 1})
      VariableStateCache.clear_variable_state(routine_id)

      assert VariableStateCache.get_variable_state(routine_id) == nil
    end
  end

  describe "get_variable_state_with_metadata/1" do
    test "returns full entry with metadata", %{routine_id: routine_id} do
      variables = %{"x" => 10}
      VariableStateCache.add_variable_state(routine_id, variables)

      entry = VariableStateCache.get_variable_state_with_metadata(routine_id)

      assert entry != nil
      assert entry.variables == variables
      assert is_integer(entry.timestamp)
      assert %DateTime{} = entry.cached_at
    end

    test "returns nil when state does not exist" do
      nonexistent_id = "nonexistent-#{:erlang.unique_integer([:positive])}"

      assert VariableStateCache.get_variable_state_with_metadata(nonexistent_id) == nil
    end
  end

  describe "clear_variable_state/1" do
    test "removes variable state for specified routine", %{routine_id: routine_id} do
      VariableStateCache.add_variable_state(routine_id, %{"x" => 1})

      assert :ok = VariableStateCache.clear_variable_state(routine_id)
      assert VariableStateCache.get_variable_state(routine_id) == nil
    end

    test "returns :ok even if variable state does not exist" do
      nonexistent_id = "nonexistent-#{:erlang.unique_integer([:positive])}"

      assert :ok = VariableStateCache.clear_variable_state(nonexistent_id)
    end

    test "does not affect other routines' variable states" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      vars_1 = %{"a" => 1}
      vars_2 = %{"b" => 2}

      VariableStateCache.add_variable_state(routine_1, vars_1)
      VariableStateCache.add_variable_state(routine_2, vars_2)

      VariableStateCache.clear_variable_state(routine_1)

      # routine_2's variable state should still exist
      assert ^vars_2 = VariableStateCache.get_variable_state(routine_2)
      assert VariableStateCache.get_variable_state(routine_1) == nil
    end
  end

  describe "clear_all/0" do
    test "removes all variable states" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      VariableStateCache.add_variable_state(routine_1, %{"a" => 1})
      VariableStateCache.add_variable_state(routine_2, %{"b" => 2})

      assert :ok = VariableStateCache.clear_all()

      assert VariableStateCache.get_variable_state(routine_1) == nil
      assert VariableStateCache.get_variable_state(routine_2) == nil
    end

    test "returns :ok even when cache is empty" do
      VariableStateCache.clear_all()

      assert :ok = VariableStateCache.clear_all()
    end
  end

  describe "get_stats/0" do
    test "returns correct routine count" do
      VariableStateCache.clear_all()

      stats = VariableStateCache.get_stats()
      assert stats.total_routines == 0

      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      VariableStateCache.add_variable_state(routine_1, %{"x" => 1})
      VariableStateCache.add_variable_state(routine_2, %{"y" => 2})

      stats = VariableStateCache.get_stats()
      assert stats.total_routines == 2
    end
  end

  describe "supervision" do
    test "starts with the application" do
      # The GenServer should be started by setup
      # Verify it's accessible by trying an operation
      routine_id = "supervision-test-#{:erlang.unique_integer([:positive])}"

      assert :ok = VariableStateCache.add_variable_state(routine_id, %{"test" => 1})
      assert %{"test" => 1} = VariableStateCache.get_variable_state(routine_id)
    end

    test "is registered as a named process" do
      # Should be able to find the process by name
      pid = Process.whereis(VariableStateCache)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "integration" do
    test "full workflow: add, get, clear" do
      routine_id = "workflow-test-#{:erlang.unique_integer([:positive])}"
      variables = %{
        "counter" => 0,
        "userName" => "test_user",
        "isActive" => true
      }

      # Store variable state
      assert :ok = VariableStateCache.add_variable_state(routine_id, variables)

      # Retrieve variable state
      assert ^variables = VariableStateCache.get_variable_state(routine_id)

      # Retrieve with metadata
      entry = VariableStateCache.get_variable_state_with_metadata(routine_id)
      assert entry.variables == variables

      # Clear variable state
      assert :ok = VariableStateCache.clear_variable_state(routine_id)

      # Verify cleared
      assert VariableStateCache.get_variable_state(routine_id) == nil
    end

    test "simulates runtime variable updates" do
      routine_id = "runtime-sim-#{:erlang.unique_integer([:positive])}"

      # Initial state
      VariableStateCache.add_variable_state(routine_id, %{"count" => 0})
      assert %{"count" => 0} = VariableStateCache.get_variable_state(routine_id)

      # Simulate increment
      VariableStateCache.add_variable_state(routine_id, %{"count" => 1})
      assert %{"count" => 1} = VariableStateCache.get_variable_state(routine_id)

      # Simulate multiple variable updates
      VariableStateCache.add_variable_state(routine_id, %{
        "count" => 5,
        "lastAction" => "increment",
        "timestamp" => 123456
      })

      vars = VariableStateCache.get_variable_state(routine_id)
      assert vars["count"] == 5
      assert vars["lastAction"] == "increment"
      assert vars["timestamp"] == 123456
    end
  end
end
