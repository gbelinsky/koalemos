defmodule Koalemos.Engine.EventHandlerTest do
  use ExUnit.Case, async: false
  alias Koalemos.Engine.{EventHandler, Observer, EventBuffer}

  # Helper to drain all messages from mailbox
  defp flush_messages do
    receive do
      _ -> flush_messages()
    after
      0 -> :ok
    end
  end

  # Test helper modules

  defmodule TestStep do
    def execute(_config, _state) do
      {:ok, []}
    end

    def handle_event(:user_input, data, _state) do
      {:ok, [add: %{user_message: data}]}
    end

    def handle_event(:timeout, _original_types, _state) do
      {:ok, [add: %{timed_out: true}]}
    end

    def handle_event(_type, _data, _state) do
      {:ok, []}
    end
  end

  defmodule TestRoutine do
    def routine_definition do
      %{
        waiting_step: %{
          type: TestStep,
          transitions: []
        }
      }
    end
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

    # Drain ALL pending messages
    :timer.sleep(10)
    flush_messages()

    # Generate unique routine ID for this test
    routine_id = "event-handler-test-#{:erlang.unique_integer([:positive])}"

    # Create a test state
    state = %{
      routine_id: routine_id,
      module: TestRoutine,
      routine_definitions: %{TestRoutine => TestRoutine.routine_definition()},
      current_routine_module: TestRoutine,
      current_step: :waiting_step,
      context: %{},
      routine_status: :running,
      auto_execute: false,
      event_buffer: EventBuffer.new(),
      waiting_for: nil,
      execution_stack: []
    }

    {:ok, state: state}
  end

  describe "handle_external_event/3" do
    test "buffers event when no one is waiting", %{state: state} do
      {:noreply, new_state} = EventHandler.handle_external_event(:user_input, "hello", state)

      # Event should be in buffer
      assert EventBuffer.size(new_state.event_buffer) == 1

      # Should record event
      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "external_event_received"
    end

    test "handles event immediately if step is waiting", %{state: state} do
      # Set up waiting state
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      state = %{state | waiting_for: %{event_types: [:user_input], from: {test_pid, make_ref()}, timer_ref: nil}}

      {:noreply, new_state} = EventHandler.handle_external_event(:user_input, "hello", state)

      # Should no longer be waiting
      assert new_state.waiting_for == nil

      # Context should be updated
      assert new_state.context.user_message == "hello"

      # Event should not be in buffer (was consumed)
      assert EventBuffer.size(new_state.event_buffer) == 0
    end

    test "ignores event if waiting for different type", %{state: state} do
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      state = %{state | waiting_for: %{event_types: [:http_response], from: {test_pid, make_ref()}, timer_ref: nil}}

      {:noreply, new_state} = EventHandler.handle_external_event(:user_input, "hello", state)

      # Should still be waiting
      assert is_map(new_state.waiting_for)

      # Event should be buffered
      assert EventBuffer.size(new_state.event_buffer) == 1
    end

    test "cancels timer when handling event", %{state: state} do
      # Set up waiting state with timer
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      {:ok, timer_ref} = :timer.send_after(10000, self(), :should_not_arrive)

      state = %{
        state
        | waiting_for: %{event_types: [:user_input], from: {test_pid, make_ref()}, timer_ref: timer_ref}
      }

      {:noreply, _new_state} = EventHandler.handle_external_event(:user_input, "hello", state)

      # Timer should be cancelled - we shouldn't receive the message
      refute_receive :should_not_arrive, 100
    end

    test "records context_changed event when event is handled", %{state: state} do
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      state = %{state | waiting_for: %{event_types: [:user_input], from: {test_pid, make_ref()}, timer_ref: nil}}

      EventHandler.handle_external_event(:user_input, "hello", state)

      # Skip external_event_received
      assert_receive {:routine_event, _}, 1000

      # Should see context_changed
      assert_receive {:routine_event, event}, 1000
      assert event.event_type == "context_changed"
    end
  end

  describe "handle_get_event/4" do
    test "returns immediately if event is already buffered", %{state: state} do
      # Pre-buffer an event
      buffer = EventBuffer.add(state.event_buffer, :user_input, "hello")
      state = %{state | event_buffer: buffer}

      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      {:reply, final_state, _} = EventHandler.handle_get_event([:user_input], nil, [], from, state)

      # Context should be updated
      assert final_state.context.user_message == "hello"

      # Buffer should be empty
      assert EventBuffer.size(final_state.event_buffer) == 0
    end

    test "sets up wait state if event not found", %{state: state} do
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      {:noreply, waiting_state} = EventHandler.handle_get_event([:user_input], nil, [], from, state)

      # Should be waiting
      assert is_map(waiting_state.waiting_for)
      assert waiting_state.waiting_for.event_types == [:user_input]
      assert waiting_state.waiting_for.from == from
      assert waiting_state.waiting_for.timer_ref == nil
    end

    test "sets up timer when timeout specified", %{state: state} do
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      {:noreply, waiting_state} = EventHandler.handle_get_event([:user_input], 5000, [], from, state)

      # Should have timer (timer_ref is {:ok, ref} tuple from :timer.send_after)
      assert is_tuple(waiting_state.waiting_for.timer_ref)

      # Clean up timer
      :timer.cancel(waiting_state.waiting_for.timer_ref)
    end

    test "returns immediately with no_event when timeout is 0", %{state: state} do
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      {:reply, final_state, _} = EventHandler.handle_get_event([:user_input], 0, [], from, state)

      # Should have no_event flag
      assert final_state.context.no_event == true

      # Should not be waiting
      assert final_state.waiting_for == nil
    end

    test "applies context diff before checking buffer", %{state: state} do
      # Pre-buffer an event
      buffer = EventBuffer.add(state.event_buffer, :user_input, "hello")
      state = %{state | event_buffer: buffer}

      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      diff = [add: %{setup_value: 42}]

      {:reply, final_state, _} = EventHandler.handle_get_event([:user_input], nil, diff, from, state)

      # Both diff and event handling should be applied
      assert final_state.context.setup_value == 42
      assert final_state.context.user_message == "hello"
    end

    test "handles invalid timeout", %{state: state} do
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      {:reply, error_state, _} = EventHandler.handle_get_event([:user_input], -1, [], from, state)

      # Should have error
      assert error_state.context.error == "Invalid timeout"
    end

    test "can wait for multiple event types", %{state: state} do
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      {:noreply, waiting_state} =
        EventHandler.handle_get_event([:user_input, :http_response], nil, [], from, state)

      # Should be waiting for both types
      assert :user_input in waiting_state.waiting_for.event_types
      assert :http_response in waiting_state.waiting_for.event_types
    end
  end

  describe "handle_timeout_event/2" do
    test "handles timeout when still waiting for same events", %{state: state} do
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      state = %{state | waiting_for: %{event_types: [:user_input], from: from, timer_ref: nil}}

      {:noreply, final_state} = EventHandler.handle_timeout_event([:user_input], state)

      # Should no longer be waiting
      assert final_state.waiting_for == nil

      # Context should have timeout flag
      assert final_state.context.timed_out == true
    end

    test "ignores stale timeout", %{state: state} do
      # State is not waiting
      {:noreply, unchanged_state} = EventHandler.handle_timeout_event([:user_input], state)

      # State should be unchanged
      assert unchanged_state == state
    end

    test "ignores timeout for different event types", %{state: state} do
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      # Waiting for :user_input
      state = %{state | waiting_for: %{event_types: [:user_input], from: from, timer_ref: nil}}

      # Timeout for :http_response (stale)
      {:noreply, unchanged_state} = EventHandler.handle_timeout_event([:http_response], state)

      # Should still be waiting
      assert is_map(unchanged_state.waiting_for)
    end
  end

  describe "integration scenarios" do
    test "wait → external event arrives → handles immediately", %{state: state} do
      # Start waiting
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      {:noreply, waiting_state} = EventHandler.handle_get_event([:user_input], nil, [], from, state)

      # External event arrives
      {:noreply, final_state} = EventHandler.handle_external_event(:user_input, "hello", waiting_state)

      # Should be handled
      assert final_state.waiting_for == nil
      assert final_state.context.user_message == "hello"
    end

    test "external event arrives → buffered → wait → handles from buffer", %{state: state} do
      # External event arrives first
      {:noreply, buffered_state} = EventHandler.handle_external_event(:user_input, "hello", state)

      # Then start waiting
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      {:reply, final_state, _} = EventHandler.handle_get_event([:user_input], nil, [], from, buffered_state)

      # Should be handled from buffer
      assert final_state.context.user_message == "hello"
      assert EventBuffer.size(final_state.event_buffer) == 0
    end

    test "wait with timeout → timeout expires → handles timeout", %{state: state} do
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      # Wait with short timeout
      {:noreply, waiting_state} = EventHandler.handle_get_event([:user_input], 50, [], from, state)

      # Wait for timeout to expire
      :timer.sleep(100)

      # Simulate timeout message
      {:noreply, final_state} = EventHandler.handle_timeout_event([:user_input], waiting_state)

      # Should have handled timeout
      assert final_state.waiting_for == nil
      assert final_state.context.timed_out == true
    end

    test "multiple events buffered, wait for specific type", %{state: state} do
      # Buffer multiple events
      {:noreply, state1} = EventHandler.handle_external_event(:event_a, "a", state)
      {:noreply, state2} = EventHandler.handle_external_event(:event_b, "b", state1)
      {:noreply, state3} = EventHandler.handle_external_event(:event_c, "c", state2)

      assert EventBuffer.size(state3.event_buffer) == 3

      # Wait for specific type
      {test_pid, _} = spawn_monitor(fn -> receive do: (:done -> :ok) end)
      from = {test_pid, make_ref()}

      {:reply, final_state, _} = EventHandler.handle_get_event([:event_b], nil, [], from, state3)

      # Should have found and removed event_b
      assert EventBuffer.size(final_state.event_buffer) == 2

      # Other events still buffered
      {:found, :event_a, "a", _, _} = EventBuffer.find_and_remove(final_state.event_buffer, [:event_a])
    end
  end
end
