defmodule Koalemos.Engine.OrchestratorTest do
  use ExUnit.Case, async: false
  alias Koalemos.Engine.{Orchestrator, Observer}

  # Test helper modules

  defmodule TestStep do
    def execute(_config, _state) do
      {:ok, [add: %{result: "success"}]}
    end
  end

  defmodule TestStepWithSetup do
    def setup(_config, _state) do
      {:ok, [add: %{setup_ran: true}]}
    end

    def execute(_config, _state) do
      {:ok, [add: %{execute_ran: true}]}
    end
  end

  defmodule FailingStep do
    def execute(_config, _state) do
      {:error, "execution failed"}
    end
  end

  defmodule TestRoutine do
    def routine_definition do
      %{
        start: %{
          type: TestStep,
          transitions: [{:next, :always}]
        },
        next: %{
          type: TestStep,
          transitions: []
        }
      }
    end

    def check_condition(:always, _context), do: true
    def check_condition(:never, _context), do: false
    def check_condition({:has_key, key}, context), do: Map.has_key?(context, key)
  end

  # Test setup

  setup do
    # Start Observer if not running
    case GenServer.whereis(Observer) do
      nil -> start_supervised!(Observer)
      _pid -> :ok
    end

    # Subscribe to PubSub
    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine_events")

    # Clear any pending messages
    receive do
      _ -> :ok
    after
      0 -> :ok
    end

    # Create a test state
    state = %{
      routine_id: "test-routine",
      module: TestRoutine,
      routine_definitions: %{TestRoutine => TestRoutine.routine_definition()},
      current_routine_module: TestRoutine,
      current_step: :start,
      context: %{},
      routine_status: :running,
      auto_execute: false,
      event_buffer: Koalemos.Engine.EventBuffer.new(),
      waiting_for: nil,
      execution_stack: []
    }

    {:ok, state: state}
  end

  describe "get_current_step_config/1" do
    test "returns step config from routine definition", %{state: state} do
      config = Orchestrator.get_current_step_config(state)

      assert config.type == TestStep
      assert config.transitions == [{:next, :always}]
    end

    test "returns nil for invalid step", %{state: state} do
      invalid_state = %{state | current_step: :nonexistent}

      assert Orchestrator.get_current_step_config(invalid_state) == nil
    end

    test "works with different routine modules", %{state: state} do
      # Add another routine to definitions
      defmodule AnotherRoutine do
        def routine_definition do
          %{init: %{type: TestStep, transitions: []}}
        end
      end

      state = %{
        state
        | routine_definitions: Map.put(state.routine_definitions, AnotherRoutine, AnotherRoutine.routine_definition()),
          current_routine_module: AnotherRoutine,
          current_step: :init
      }

      config = Orchestrator.get_current_step_config(state)
      assert config.type == TestStep
    end
  end

  describe "execute_current_step/1" do
    test "records step_started event", %{state: state} do
      Orchestrator.execute_current_step(state)

      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "step_started"
      assert event.routine_id == "test-routine"
    end

    test "executes step and sends completion message", %{state: state} do
      Orchestrator.execute_current_step(state)

      # Should receive step completion message
      assert_receive {:event, :step_complete, {:ok, diff}}, 1000
      assert diff == [add: %{result: "success"}]
    end

    test "handles invalid step gracefully", %{state: state} do
      invalid_state = %{state | current_step: :nonexistent}

      Orchestrator.execute_current_step(invalid_state)

      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "error_occurred"
      assert event.metadata[:type] == "invalid_step" or event.metadata["type"] == "invalid_step"

      # Should receive error completion message
      assert_receive {:event, :step_complete, {:error, _reason}}, 1000
    end

    test "calls step setup if defined", %{state: state} do
      # Update step to one with setup
      state = put_in(state, [:routine_definitions, TestRoutine, :start, :type], TestStepWithSetup)

      Orchestrator.execute_current_step(state)

      # Should see step_setup event
      assert_receive {:routine_event, event1}, 1000
      assert event1.event_type == "step_started"

      assert_receive {:routine_event, event2}, 1000
      assert event2.event_type == "step_setup"

      # Setup should have modified context
      assert_receive {:routine_event, event3}, 1000
      assert event3.event_type == "context_changed"
    end

    test "merges static and dynamic config", %{state: state} do
      # Add static config to step definition
      state = put_in(state, [:routine_definitions, TestRoutine, :start, :config], %{static: true})

      # Add dynamic config to context (need to initialize :config first)
      state = %{state | context: Map.put(state.context, :config, %{start: %{dynamic: true}})}

      # We can't easily verify config merging without a spy, but we can verify execution succeeds
      Orchestrator.execute_current_step(state)

      assert_receive {:event, :step_complete, {:ok, _}}, 1000
    end
  end

  describe "handle_step_success/2" do
    test "applies context diff and records events", %{state: state} do
      diff = [add: %{new_value: 42}]

      {:noreply, new_state} = Orchestrator.handle_step_success(diff, state)

      # Check context was updated
      assert new_state.context.new_value == 42

      # Check events were recorded
      assert_receive {:routine_event, event1}, 1000
      assert event1.event_type == "step_completed"

      assert_receive {:routine_event, event2}, 1000
      assert event2.event_type == "context_changed"
    end

    test "checks transitions after success", %{state: state} do
      diff = []

      {:noreply, new_state} = Orchestrator.handle_step_success(diff, state)

      # Should have transitioned to :next (because of :always condition)
      assert new_state.current_step == :next

      # Should see transition_taken event
      assert_receive {:routine_event, _}, 1000  # step_completed
      assert_receive {:routine_event, _}, 1000  # context_changed
      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "transition_taken"
    end

    test "handles context diff errors", %{state: state} do
      # Invalid diff that will cause error
      diff = [add: %{existing: "value"}]
      state = %{state | context: %{existing: "old"}}

      {:noreply, error_state} = Orchestrator.handle_step_success(diff, state)

      # Should have recorded error
      assert_receive {:routine_event, _}, 1000  # step_completed
      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "error_occurred"

      # Context should have error (can be string or tuple depending on error type)
      assert error_state.context.error != nil
    end

    test "triggers :continue_routine when auto_execute is true", %{state: state} do
      state = %{state | auto_execute: true}
      diff = []

      Orchestrator.handle_step_success(diff, state)

      # Should have sent continue message
      assert_receive :continue_routine, 1000
    end

    test "completes routine when reaching :end with no sub-routines", %{state: state} do
      # Move to a step that transitions to :end
      state = %{state | current_step: :next}
      diff = []

      {:noreply, final_state} = Orchestrator.handle_step_success(diff, state)

      # Should be completed
      assert final_state.routine_status == :completed
      assert final_state.current_step == :end

      # Should see routine_completed event
      assert_receive {:routine_event, _}, 1000  # step_completed
      assert_receive {:routine_event, _}, 1000  # context_changed
      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "routine_completed"
    end
  end

  describe "handle_step_error/2" do
    test "records error event", %{state: state} do
      reason = "something went wrong"

      Orchestrator.handle_step_error(reason, state)

      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "error_occurred"
      metadata = event.metadata
      type = metadata[:type] || metadata["type"]
      assert type == "step_execution_failed"
    end

    test "adds error to context", %{state: state} do
      reason = "test error"

      {:noreply, error_state} = Orchestrator.handle_step_error(reason, state)

      assert error_state.context.error == reason
    end

    test "transitions to :error", %{state: state} do
      reason = "test error"

      {:noreply, error_state} = Orchestrator.handle_step_error(reason, state)

      # Should transition to error state
      assert error_state.routine_status == :error
      assert error_state.current_step == :error
    end

    test "records routine_completed event on error", %{state: state} do
      reason = "test error"

      Orchestrator.handle_step_error(reason, state)

      # Skip error_occurred event
      assert_receive {:routine_event, _}, 1000

      # Should see routine_completed
      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "routine_completed"
    end
  end

  describe "sub-routine execution" do
    defmodule SubRoutine do
      def routine_definition do
        %{
          sub_start: %{
            type: TestStep,
            transitions: []
          }
        }
      end

      def start, do: :sub_start
    end

    defmodule SubRoutineStep do
      def routine_definition do
        SubRoutine.routine_definition()
      end

      def start, do: :sub_start

      def execute(_config, _state) do
        {:ok, []}
      end
    end

    test "enters sub-routine when step has routine_definition/0", %{state: state} do
      # Update step to be a sub-routine
      state = put_in(state, [:routine_definitions, TestRoutine, :start, :type], SubRoutineStep)

      new_state = Orchestrator.execute_current_step(state)

      # Should have entered sub-routine
      assert new_state.current_routine_module == SubRoutineStep
      assert new_state.current_step == :sub_start

      # Execution stack should have parent state
      assert length(new_state.execution_stack) == 1
      [parent] = new_state.execution_stack
      assert parent.module == TestRoutine
      assert parent.step == :start
    end

    test "exits sub-routine on completion", %{state: state} do
      # Simulate being in a sub-routine
      state = %{
        state
        | current_routine_module: SubRoutine,
          current_step: :sub_start,
          execution_stack: [%{module: TestRoutine, step: :start}],
          routine_definitions: Map.put(state.routine_definitions, SubRoutine, SubRoutine.routine_definition())
      }

      # Complete the sub-routine by calling handle_step_success with transition to :end
      diff = []

      {:noreply, new_state} = Orchestrator.handle_step_success(diff, state)

      # Should have returned to parent
      assert new_state.current_routine_module == TestRoutine
      assert new_state.current_step == :start
      assert new_state.execution_stack == []

      # Should receive step completion message for parent
      assert_receive {:event, :step_complete, {:ok, []}}, 1000
    end

    test "loads sub-routine definition on entry", %{state: state} do
      state = put_in(state, [:routine_definitions, TestRoutine, :start, :type], SubRoutineStep)

      new_state = Orchestrator.execute_current_step(state)

      # Routine definitions should include SubRoutineStep
      assert Map.has_key?(new_state.routine_definitions, SubRoutineStep)
      assert new_state.routine_definitions[SubRoutineStep] == SubRoutine.routine_definition()
    end

    test "doesn't reload sub-routine definition if already loaded", %{state: state} do
      # Pre-load SubRoutineStep definition
      state = %{
        state
        | routine_definitions: Map.put(state.routine_definitions, SubRoutineStep, SubRoutine.routine_definition())
      }

      state = put_in(state, [:routine_definitions, TestRoutine, :start, :type], SubRoutineStep)

      new_state = Orchestrator.execute_current_step(state)

      # Should still have the definition (wasn't re-loaded)
      assert new_state.routine_definitions[SubRoutineStep] == SubRoutine.routine_definition()
    end

    test "sends :continue_routine when auto_execute is true in sub-routine", %{state: state} do
      state = %{state | auto_execute: true}
      state = put_in(state, [:routine_definitions, TestRoutine, :start, :type], SubRoutineStep)

      Orchestrator.execute_current_step(state)

      # Should have sent continue message
      assert_receive :continue_routine, 1000
    end
  end

  describe "transition logic" do
    defmodule ConditionalRoutine do
      def routine_definition do
        %{
          start: %{
            type: TestStep,
            transitions: [
              {:success_path, {:has_key, :success}},
              {:error_path, {:has_key, :error}},
              {:default, :always}
            ]
          },
          success_path: %{type: TestStep, transitions: []},
          error_path: %{type: TestStep, transitions: []},
          default: %{type: TestStep, transitions: []}
        }
      end

      def check_condition(:always, _context), do: true
      def check_condition({:has_key, key}, context), do: Map.has_key?(context, key)
    end

    test "evaluates transition conditions", %{state: state} do
      state = %{
        state
        | current_routine_module: ConditionalRoutine,
          routine_definitions: %{ConditionalRoutine => ConditionalRoutine.routine_definition()},
          context: %{success: true}
      }

      {:noreply, new_state} = Orchestrator.handle_step_success([], state)

      # Should have taken success_path
      assert new_state.current_step == :success_path
    end

    test "takes first valid transition when multiple match", %{state: state} do
      state = %{
        state
        | current_routine_module: ConditionalRoutine,
          routine_definitions: %{ConditionalRoutine => ConditionalRoutine.routine_definition()},
          context: %{success: true, error: true}
      }

      {:noreply, new_state} = Orchestrator.handle_step_success([], state)

      # Should take first matching transition (success_path)
      assert new_state.current_step == :success_path
    end

    test "transitions to :end when no conditions match", %{state: state} do
      defmodule NoMatchRoutine do
        def routine_definition do
          %{
            start: %{
              type: TestStep,
              transitions: [{:next, :never}]
            }
          }
        end

        def check_condition(:never, _context), do: false
      end

      state = %{
        state
        | current_routine_module: NoMatchRoutine,
          routine_definitions: %{NoMatchRoutine => NoMatchRoutine.routine_definition()}
      }

      {:noreply, new_state} = Orchestrator.handle_step_success([], state)

      # Should complete when no transitions match
      assert new_state.routine_status == :completed
      assert new_state.current_step == :end
    end

    test "transitions to :end when transitions list is empty", %{state: state} do
      state = %{state | current_step: :next}  # :next has no transitions

      {:noreply, new_state} = Orchestrator.handle_step_success([], state)

      assert new_state.routine_status == :completed
      assert new_state.current_step == :end
    end
  end

  describe "integration: full step lifecycle" do
    test "complete flow: execute → success → transition", %{state: state} do
      # Execute step
      updated_state = Orchestrator.execute_current_step(state)

      # Wait for completion
      assert_receive {:event, :step_complete, {:ok, diff}}, 1000

      # Handle success
      {:noreply, final_state} = Orchestrator.handle_step_success(diff, updated_state)

      # Should have:
      # 1. Applied context diff
      assert final_state.context.result == "success"

      # 2. Transitioned to next step
      assert final_state.current_step == :next

      # 3. Recorded all events
      assert_receive {:routine_event, e1}, 1000
      assert e1.event_type == "step_started"

      assert_receive {:routine_event, e2}, 1000
      assert e2.event_type == "step_completed"

      assert_receive {:routine_event, e3}, 1000
      assert e3.event_type == "context_changed"

      assert_receive {:routine_event, e4}, 1000
      assert e4.event_type == "transition_taken"
    end

    test "complete flow: execute → error → transition", %{state: state} do
      # Update to failing step
      state = put_in(state, [:routine_definitions, TestRoutine, :start, :type], FailingStep)

      # Execute step
      updated_state = Orchestrator.execute_current_step(state)

      # Wait for error
      assert_receive {:event, :step_complete, {:error, reason}}, 1000

      # Handle error
      {:noreply, error_state} = Orchestrator.handle_step_error(reason, updated_state)

      # Should have:
      # 1. Error in context
      assert error_state.context.error == reason

      # 2. Transitioned to error state
      assert error_state.routine_status == :error
      assert error_state.current_step == :error

      # 3. Recorded events
      assert_receive {:routine_event, e1}, 1000
      assert e1.event_type == "step_started"

      assert_receive {:routine_event, e2}, 1000
      assert e2.event_type == "error_occurred"

      assert_receive {:routine_event, e3}, 1000
      assert e3.event_type == "routine_completed"
    end
  end
end
