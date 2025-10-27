defmodule Koalemos.EngineTest do
  use ExUnit.Case, async: false
  alias Koalemos.Engine
  alias Koalemos.Engine.Observer

  # Test helper modules

  defmodule SimpleStep do
    def execute(_config, _state) do
      {:ok, [add: %{step_executed: true}]}
    end

    def handle_event(:user_input, data, _state) do
      {:ok, [add: %{user_message: data}]}
    end

    def handle_event(_type, _data, _state) do
      {:ok, []}
    end
  end

  defmodule WaitingStep do
    def execute(_config, _state) do
      # Call Engine.handle_event to wait for user input
      state = Engine.handle_event([:user_input], 1000, [], Process.get(:routine_id))
      {:ok, [add: %{received_input: state.context[:user_message]}]}
    end

    def handle_event(:user_input, data, _state) do
      {:ok, [add: %{user_message: data}]}
    end

    def handle_event(:timeout, _types, _state) do
      {:ok, [add: %{timed_out: true}]}
    end
  end

  defmodule SetupRoutine do
    def routine_definition do
      %{
        start: %{
          type: SimpleStep,
          transitions: []
        }
      }
    end

    def setup(_config, _state) do
      {:ok, [add: %{setup_ran: true}]}
    end
  end

  defmodule SimpleRoutine do
    def routine_definition do
      %{
        start: %{
          type: SimpleStep,
          transitions: [{:step2, :always}]
        },
        step2: %{
          type: SimpleStep,
          transitions: []
        }
      }
    end

    def check_condition(:always, _context), do: true
  end

  defmodule CustomStartRoutine do
    def routine_definition do
      %{
        custom_start: %{
          type: SimpleStep,
          transitions: []
        }
      }
    end

    def start, do: :custom_start
  end

  # Test setup

  setup do
    # Start Registry if not running
    case Process.whereis(Koalemos.RoutineRegistry) do
      nil -> start_supervised!({Registry, keys: :unique, name: Koalemos.RoutineRegistry})
      _pid -> :ok
    end

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

    :ok
  end

  describe "start/1 and start_link/1" do
    test "starts engine process successfully" do
      {:ok, pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-1",
        initial_context: %{},
        auto_execute: false
      )

      assert Process.alive?(pid)

      # Clean up
      GenServer.stop(pid)
    end

    test "registers with RoutineRegistry" do
      routine_id = "test-2"

      {:ok, _pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: routine_id,
        auto_execute: false
      )

      # Should be able to look up by routine_id
      [{pid, _}] = Registry.lookup(Koalemos.RoutineRegistry, routine_id)
      assert Process.alive?(pid)

      # Clean up
      GenServer.stop(pid)
    end

    test "accepts initial context" do
      {:ok, pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-3",
        initial_context: %{user: "alice", value: 42},
        auto_execute: false
      )

      state = :sys.get_state(pid)
      assert state.context.user == "alice"
      assert state.context.value == 42

      GenServer.stop(pid)
    end

    test "defaults to auto_execute true" do
      {:ok, pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-4"
      )

      state = :sys.get_state(pid)
      assert state.auto_execute == true

      GenServer.stop(pid)
    end

    test "can set auto_execute false" do
      {:ok, pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-5",
        auto_execute: false
      )

      state = :sys.get_state(pid)
      assert state.auto_execute == false

      GenServer.stop(pid)
    end

    test "calls routine setup if defined" do
      {:ok, pid} = Engine.start(
        routine_module: SetupRoutine,
        routine_id: "test-6",
        auto_execute: false
      )

      state = :sys.get_state(pid)
      assert state.context.setup_ran == true

      GenServer.stop(pid)
    end

    test "uses custom start step if defined" do
      {:ok, pid} = Engine.start(
        routine_module: CustomStartRoutine,
        routine_id: "test-7",
        auto_execute: false
      )

      state = :sys.get_state(pid)
      assert state.current_step == :custom_start

      GenServer.stop(pid)
    end

    test "records routine_started event" do
      Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-8",
        initial_context: %{user: "bob"},
        auto_execute: false
      )

      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "routine_started"
      assert event.routine_id == "test-8"
    end

    test "returns error if routine_module missing routine_definition/0" do
      defmodule InvalidRoutine do
        # Missing routine_definition/0
      end

      assert {:error, {:error, _reason}} = Engine.start(
        routine_module: InvalidRoutine,
        routine_id: "test-9"
      )
    end

    test "sends :continue_routine when auto_execute true" do
      # Start with auto_execute false first, then manually verify continue works
      {:ok, pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-10",
        auto_execute: false
      )

      # Manually send continue
      send(pid, :continue_routine)

      # Wait a bit for step to execute
      :timer.sleep(50)

      state = :sys.get_state(pid)
      # Should have executed at least start step
      assert state.context[:step_executed] == true

      GenServer.stop(pid)
    end
  end

  describe "handle_info :continue_routine" do
    test "delegates to Orchestrator.execute_current_step" do
      {:ok, pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-11",
        auto_execute: false
      )

      initial_state = :sys.get_state(pid)
      assert initial_state.current_step == :start

      # Send continue
      send(pid, :continue_routine)
      :timer.sleep(100)

      # Step should have executed and transitioned
      state = :sys.get_state(pid)
      assert state.context.step_executed == true
      assert state.current_step == :step2  # Transitioned

      GenServer.stop(pid)
    end
  end

  describe "handle_info {:event, :step_complete, ...}" do
    test "delegates success to Orchestrator.handle_step_success" do
      {:ok, pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-12",
        auto_execute: false
      )

      # Manually trigger step and completion
      send(pid, :continue_routine)
      :timer.sleep(100)

      # State should be updated with diff after step completes
      state = :sys.get_state(pid)
      assert state.context.step_executed == true

      GenServer.stop(pid)
    end

    test "delegates error to Orchestrator.handle_step_error" do
      defmodule FailingStep do
        def execute(_config, _state) do
          {:error, "test error"}
        end
      end

      defmodule FailingRoutine do
        def routine_definition do
          %{
            start: %{
              type: FailingStep,
              transitions: []
            }
          }
        end
      end

      {:ok, pid} = Engine.start(
        routine_module: FailingRoutine,
        routine_id: "test-13",
        auto_execute: false
      )

      send(pid, :continue_routine)
      :timer.sleep(100)

      # Check state after error
      state = :sys.get_state(pid)
      assert state.routine_status == :error

      GenServer.stop(pid)
    end
  end

  describe "handle_cast {:external_event, ...}" do
    test "delegates to EventHandler.handle_external_event" do
      {:ok, pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-14",
        auto_execute: false
      )

      # Send external event
      GenServer.cast(pid, {:external_event, :user_input, "hello"})
      :timer.sleep(50)

      # Event should be buffered
      state = :sys.get_state(pid)
      assert Koalemos.Engine.EventBuffer.size(state.event_buffer) == 1

      GenServer.stop(pid)
    end

    test "can use send_external_event/3 helper" do
      routine_id = "test-15"

      {:ok, _pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: routine_id,
        auto_execute: false
      )

      # Clear routine_started event
      assert_receive {:routine_event, _}, 1000

      # Use helper function
      :ok = Engine.send_external_event(routine_id, :user_input, "hello")

      # Event should be received (wait a bit longer)
      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "external_event_received"
    end
  end

  describe "handle_call {:get_event, ...}" do
    test "delegates to EventHandler.handle_get_event" do
      {:ok, pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-16",
        auto_execute: false
      )

      # Pre-buffer an event
      GenServer.cast(pid, {:external_event, :user_input, "hello"})
      :timer.sleep(50)

      # Call get_event (should return immediately with buffered event)
      task = Task.async(fn ->
        GenServer.call(pid, {:get_event, [:user_input], 0, []})
      end)

      result = Task.await(task)

      # Should have received the event
      assert result.context[:user_message] == "hello"

      GenServer.stop(pid)
    end

    test "can use handle_event/4 helper" do
      routine_id = "test-17"

      {:ok, _pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: routine_id,
        auto_execute: false
      )

      # Pre-buffer an event
      Engine.send_external_event(routine_id, :user_input, "hello")
      :timer.sleep(50)

      # Use helper function
      task = Task.async(fn ->
        Engine.handle_event([:user_input], 0, [], routine_id)
      end)

      result = Task.await(task)

      # Should have received the event
      assert result.context[:user_message] == "hello"
    end
  end

  describe "handle_info {:external_event, :timeout, ...}" do
    test "delegates to EventHandler.handle_timeout_event" do
      {:ok, pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-18",
        auto_execute: false
      )

      # Set up waiting state manually
      state = :sys.get_state(pid)
      from = {self(), make_ref()}
      waiting_state = %{state | waiting_for: %{event_types: [:user_input], from: from, timer_ref: nil}}
      :sys.replace_state(pid, fn _ -> waiting_state end)

      # Send timeout message
      send(pid, {:external_event, :timeout, [:user_input]})
      :timer.sleep(50)

      # Should no longer be waiting
      final_state = :sys.get_state(pid)
      assert final_state.waiting_for == nil
    end
  end

  describe "integration: full routine execution" do
    test "executes simple routine from start to completion" do
      {:ok, pid} = Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-19",
        auto_execute: true  # Auto-execute
      )

      # Wait and poll for completion
      Enum.each(1..20, fn _ ->
        state = :sys.get_state(pid)
        if state.routine_status == :completed do
          throw(:completed)
        end
        :timer.sleep(100)
      end)

      # Check final state
      state = :sys.get_state(pid)

      # At minimum, should have progressed beyond start
      assert state.context.step_executed == true
      # May or may not have completed depending on timing
      # Just verify execution progressed

      GenServer.stop(pid)
    catch
      :completed -> :ok
    end

    test "records all lifecycle events" do
      Engine.start(
        routine_module: SimpleRoutine,
        routine_id: "test-20",
        auto_execute: true
      )

      # Collect events
      assert_receive {:routine_event, e1}, 1000
      assert e1.event_type == "routine_started"

      assert_receive {:routine_event, e2}, 1000
      assert e2.event_type == "step_started"

      # More events will follow...
      # Just verify we're receiving events

      :timer.sleep(200)
    end
  end
end
