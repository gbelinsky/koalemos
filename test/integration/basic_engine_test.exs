defmodule Koalemos.Integration.BasicEngineTest do
  use Koalemos.IntegrationTestCase, async: false

  # Simple test steps
  defmodule ConfigStep do
    def execute(_config, _state) do
      {:ok, [add: %{config_ran: true}]}
    end
  end

  defmodule ActionStep do
    def execute(_config, state) do
      value = Map.get(state.context, :input_value, 10)
      {:ok, [add: %{result: value * 2}]}
    end
  end

  defmodule CounterStep do
    def execute(_config, state) do
      count = Map.get(state.context, :count, 0)
      {:ok, [add: %{count: count + 1}]}
    end
  end

  defmodule FailingStep do
    def execute(_config, _state) do
      {:error, "intentional failure"}
    end
  end

  # Test routines
  defmodule SingleStepRoutine do
    def routine_definition do
      %{
        start: %{
          type: Koalemos.Integration.BasicEngineTest.ConfigStep,
          transitions: []
        }
      }
    end
  end

  defmodule MultiStepRoutine do
    def routine_definition do
      %{
        start: %{
          type: Koalemos.Integration.BasicEngineTest.ConfigStep,
          transitions: [{:middle, :always}]
        },
        middle: %{
          type: Koalemos.Integration.BasicEngineTest.ActionStep,
          transitions: [{:final, :always}]
        },
        final: %{
          type: Koalemos.Integration.BasicEngineTest.CounterStep,
          transitions: []
        }
      }
    end

    def check_condition(:always, _context), do: true
  end

  defmodule FailingRoutine do
    def routine_definition do
      %{
        start: %{
          type: Koalemos.Integration.BasicEngineTest.FailingStep,
          transitions: []
        }
      }
    end
  end

  describe "single-step routine execution" do
    test "starts engine and runs simple routine", %{routine_id: routine_id} do
      {:ok, pid} = EngineManager.start_routine(routine_id, SingleStepRoutine, %{})

      # Engine should be alive
      assert Process.alive?(pid)

      # Wait for routine to complete
      assert_receive {:routine_event, %{event_type: "routine_completed"}}, 1000

      # Check state
      state = :sys.get_state(pid)
      assert state.context.config_ran == true
      assert state.routine_status == :completed
    end

    test "accepts and uses initial context", %{routine_id: routine_id} do
      {:ok, pid} = EngineManager.start_routine(routine_id, SingleStepRoutine, %{initial_key: "value"})

      assert_receive {:routine_event, %{event_type: "routine_completed"}}, 1000

      state = :sys.get_state(pid)
      assert state.context.initial_key == "value"
      assert state.context.config_ran == true
    end
  end

  describe "multi-step routine with transitions" do
    test "executes steps in correct order", %{routine_id: routine_id} do
      {:ok, pid} = EngineManager.start_routine(routine_id, MultiStepRoutine, %{input_value: 5})

      # Wait for completion
      assert_receive {:routine_event, %{event_type: "routine_completed"}}, 1000

      # Check that all steps ran in order
      state = :sys.get_state(pid)
      assert state.context.config_ran == true     # First step
      assert state.context.result == 10          # Second step (5 * 2)
      assert state.context.count == 1            # Third step
      assert state.current_step == :end
      assert state.routine_status == :completed
    end

    test "context flows between steps", %{routine_id: routine_id} do
      {:ok, pid} = EngineManager.start_routine(routine_id, MultiStepRoutine, %{input_value: 20})

      assert_receive {:routine_event, %{event_type: "routine_completed"}}, 1000

      state = :sys.get_state(pid)
      # Second step should have used input_value from initial context
      assert state.context.result == 40
    end

    test "emits events for each step", %{routine_id: routine_id} do
      {:ok, _pid} = EngineManager.start_routine(routine_id, MultiStepRoutine, %{})

      # Should see step_started events
      assert_receive {:routine_event, %{event_type: "step_started"}}, 1000
      assert_receive {:routine_event, %{event_type: "step_completed"}}, 1000

      # Drain remaining events
      assert_receive {:routine_event, %{event_type: "step_started"}}, 1000
      assert_receive {:routine_event, %{event_type: "step_completed"}}, 1000
      assert_receive {:routine_event, %{event_type: "step_started"}}, 1000
      assert_receive {:routine_event, %{event_type: "step_completed"}}, 1000

      assert_receive {:routine_event, %{event_type: "routine_completed"}}, 1000
    end
  end

  describe "registry integration" do
    test "starts multiple routines and tracks in registry" do
      id1 = "registry-test-1-#{:erlang.unique_integer([:positive])}"
      id2 = "registry-test-2-#{:erlang.unique_integer([:positive])}"
      id3 = "registry-test-3-#{:erlang.unique_integer([:positive])}"

      {:ok, pid1} = EngineManager.start_routine(id1, SingleStepRoutine, %{})
      {:ok, pid2} = EngineManager.start_routine(id2, SingleStepRoutine, %{})
      {:ok, pid3} = EngineManager.start_routine(id3, SingleStepRoutine, %{})

      # All should be in registry
      assert [{^pid1, _}] = Registry.lookup(Koalemos.RoutineRegistry, id1)
      assert [{^pid2, _}] = Registry.lookup(Koalemos.RoutineRegistry, id2)
      assert [{^pid3, _}] = Registry.lookup(Koalemos.RoutineRegistry, id3)

      # Cleanup
      GenServer.stop(pid1, :normal, 100)
      GenServer.stop(pid2, :normal, 100)
      GenServer.stop(pid3, :normal, 100)
    end

    test "looks up routine by ID", %{routine_id: routine_id} do
      {:ok, pid} = EngineManager.start_routine(routine_id, SingleStepRoutine, %{})

      # Should be able to look up
      assert [{^pid, _}] = Registry.lookup(Koalemos.RoutineRegistry, routine_id)
    end

    test "returns existing pid if already started", %{routine_id: routine_id} do
      {:ok, pid1} = EngineManager.start_routine(routine_id, SingleStepRoutine, %{})
      {:ok, pid2} = EngineManager.start_routine(routine_id, SingleStepRoutine, %{})

      assert pid1 == pid2
    end

    test "cleans up from registry when stopped", %{routine_id: routine_id} do
      {:ok, pid} = EngineManager.start_routine(routine_id, SingleStepRoutine, %{})

      # Should be in registry
      assert [{^pid, _}] = Registry.lookup(Koalemos.RoutineRegistry, routine_id)

      # Stop it
      GenServer.stop(pid, :normal, 100)

      # Should be gone from registry
      :timer.sleep(50)
      assert [] = Registry.lookup(Koalemos.RoutineRegistry, routine_id)
    end
  end

  describe "error handling integration" do
    test "handles step error gracefully", %{routine_id: routine_id} do
      {:ok, pid} = EngineManager.start_routine(routine_id, FailingRoutine, %{})

      # Should receive error event
      assert_receive {:routine_event, %{event_type: "error_occurred"}}, 1000

      # Routine should complete (with error in context)
      assert_receive {:routine_event, %{event_type: "routine_completed"}}, 1000

      # Engine should still be alive
      assert Process.alive?(pid)

      # Error should be in context
      state = :sys.get_state(pid)
      assert state.context.error == "intentional failure"
    end
  end
end
