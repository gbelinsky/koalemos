defmodule Koalemos.Engine.EventHandler do
  @moduledoc """
  Handles external events and event waiting logic for routines.

  The EventHandler manages the interaction between external events (user input,
  external triggers) and steps that are waiting for those events. It uses the
  EventBuffer to store incoming events and matches them against waiting steps.

  ## Responsibilities

  - **Buffer external events** - Store events that arrive when no step is waiting
  - **Match events to waiters** - When an event arrives, check if a step is waiting for it
  - **Manage timeouts** - Set timers when steps wait with timeout, handle expiry
  - **Call step callbacks** - Invoke step's `handle_event/3` when event matches

  ## Event Flow

  ### External Event Arrives:
  ```
  1. EventHandler.handle_external_event(type, data, state)
  2. Add to EventBuffer
  3. If step is waiting for this type:
     - Find and remove from buffer
     - Call step's handle_event/3
     - Apply context diff
     - Reply to waiting caller
  4. Else: keep buffered
  ```

  ### Step Waits for Event:
  ```
  1. EventHandler.handle_get_event(types, timeout, diff, from, state)
  2. Apply context diff first
  3. Try to find event in buffer
  4. If found:
     - Call step's handle_event/3
     - Reply immediately
  5. Else:
     - Set up wait state
     - Set timer if timeout specified
     - Block caller until event arrives or timeout
  ```

  ### Timeout Expires:
  ```
  1. EventHandler.handle_timeout_event(types, state)
  2. If still waiting for these types:
     - Call step's handle_event/3 with :timeout
     - Reply to caller
  3. Else: ignore (stale timeout)
  ```

  ## State Fields

  The EventHandler reads and updates these fields in the engine state:

  - `event_buffer` - EventBuffer holding pending events
  - `waiting_for` - Map with `%{event_types: [...], from: pid, timer_ref: ref}` or `nil`

  ## Used By

  Called by Engine GenServer in response to:
  - `handle_call({:get_event, ...}, from, state)` → EventHandler.handle_get_event
  - `handle_cast({:external_event, ...}, state)` → EventHandler.handle_external_event
  - `handle_info({:external_event, :timeout, ...}, state)` → EventHandler.handle_timeout_event
  """

  alias Koalemos.Engine.{EventRecorder, StepUtils, Orchestrator, EventBuffer, ContextManager}

  @type state :: map()
  @type event_type :: atom()
  @type event_types :: [event_type()]
  @type event_data :: term()
  @type timeout_ms :: non_neg_integer() | nil
  @type genserver_result :: {:noreply, state()} | {:reply, state(), state()}

  @doc """
  Handles incoming external events, buffering them and checking if any waiting step can be satisfied.

  When an external event arrives, this function:
  1. Records the event
  2. Adds it to the event buffer
  3. If a step is waiting for this event type, attempts to handle it immediately

  ## Parameters

  - `event_type` - The type of event (e.g., `:user_input`, `:http_response`)
  - `data` - The event data (any term)
  - `state` - The current engine state

  ## Returns

  GenServer tuple `{:noreply, updated_state}`

  ## Examples

      # Called by Engine GenServer
      def handle_cast({:external_event, type, data}, state) do
        EventHandler.handle_external_event(type, data, state)
      end
  """
  @spec handle_external_event(event_type(), event_data(), state()) :: genserver_result()
  def handle_external_event(event_type, data, state) do
    EventRecorder.record_event(state, "external_event_received", %{
      metadata: %{event_type: event_type, data: data}
    })

    # Always buffer the event first
    buffer = Map.get(state, :event_buffer, EventBuffer.new())
    new_buffer = EventBuffer.add(buffer, event_type, data)
    updated_state = %{state | event_buffer: new_buffer}

    # Try to handle if we're waiting for this event type
    case state.waiting_for do
      %{event_types: types, from: from, timer_ref: timer_ref} ->
        if event_type in types do
          case try_handle_event_from_buffer([event_type], updated_state) do
            {:found, final_state} ->
              cancel_timer_and_reply(%{from: from, timer_ref: timer_ref}, final_state)

            :not_found ->
              # Shouldn't happen since we just added it
              {:noreply, updated_state}
          end
        else
          # Not waiting for this event type
          {:noreply, updated_state}
        end

      _ ->
        # Not waiting at all
        {:noreply, updated_state}
    end
  end

  @doc """
  Handles routine waiting for specific event types with optional timeout.

  When a step calls `Engine.handle_event(routine_id, event_types, timeout, diff)`,
  this function is invoked. It:
  1. Applies the context diff
  2. Tries to find a matching event in the buffer
  3. If found, handles it immediately
  4. If not found, sets up wait state (with optional timeout)

  ## Parameters

  - `event_types` - List of event types to wait for (e.g., `[:user_input, :timeout]`)
  - `timeout` - Timeout in milliseconds, `nil` for infinite, `0` for no wait
  - `diff` - Context diff to apply before waiting
  - `from` - GenServer from tuple (caller to reply to)
  - `state` - The current engine state

  ## Returns

  GenServer tuple - either `{:reply, state, state}` or `{:noreply, state}`

  ## Examples

      # Called by Engine GenServer
      def handle_call({:get_event, types, timeout, diff}, from, state) do
        EventHandler.handle_get_event(types, timeout, diff, from, state)
      end
  """
  @spec handle_get_event(
          event_types(),
          timeout_ms(),
          ContextManager.diff(),
          GenServer.from(),
          state()
        ) ::
          genserver_result()
  def handle_get_event(event_types, timeout, diff, from, state) do
    # Apply the context diff first
    updated_state = ContextManager.apply_context_diff!(state, diff)

    # Try to find a matching event in the buffer
    case try_handle_event_from_buffer(event_types, updated_state) do
      {:found, final_state} ->
        {:reply, final_state, final_state}

      :not_found ->
        setup_wait_state(event_types, timeout, from, updated_state)
    end
  end

  @doc """
  Handles timeout events for waiting routines.

  When a timer expires for a waiting step, this function is invoked. It:
  1. Checks if we're still waiting for these event types (timeout might be stale)
  2. If yes, calls the step's `handle_event/3` with `:timeout`
  3. If no, ignores the timeout (stale)

  ## Parameters

  - `original_event_types` - The event types that were being waited for
  - `state` - The current engine state

  ## Returns

  GenServer tuple `{:noreply, updated_state}`

  ## Examples

      # Called by Engine GenServer
      def handle_info({:external_event, :timeout, event_types}, state) do
        EventHandler.handle_timeout_event(event_types, state)
      end
  """
  @spec handle_timeout_event(event_types(), state()) :: genserver_result()
  def handle_timeout_event(original_event_types, state) do
    case state.waiting_for do
      %{event_types: ^original_event_types, from: from} ->
        # This timeout matches our current wait - handle it
        step_config = Orchestrator.get_current_step_config(state)

        final_state =
          StepUtils.call_step_function_if_exists(
            step_config.type,
            :handle_event,
            [:timeout, original_event_types],
            state
          )

        GenServer.reply(from, final_state)
        {:noreply, %{final_state | waiting_for: nil}}

      _ ->
        # Stale timeout - ignore completely
        {:noreply, state}
    end
  end

  # Private helper functions

  # Sets up the wait state based on timeout value
  defp setup_wait_state(event_types, timeout, from, state) do
    case timeout do
      0 ->
        # Don't wait - return immediately with no event found
        no_event_state = ContextManager.apply_context_diff!(state, add: %{no_event: true})
        {:reply, no_event_state, no_event_state}

      nil ->
        # Wait forever
        waiting_state = %{
          state
          | waiting_for: %{event_types: event_types, from: from, timer_ref: nil}
        }

        {:noreply, waiting_state}

      ms when is_integer(ms) and ms > 0 ->
        # Wait for specified time
        timer_ref = :timer.send_after(ms, self(), {:external_event, :timeout, event_types})

        waiting_state = %{
          state
          | waiting_for: %{event_types: event_types, from: from, timer_ref: timer_ref}
        }

        {:noreply, waiting_state}

      _ ->
        # Invalid timeout
        error_state =
          ContextManager.apply_context_diff!(state, add: %{error: "Invalid timeout"})

        {:reply, error_state, error_state}
    end
  end

  # Cancels timer (if set) and replies to waiting caller
  defp cancel_timer_and_reply(waiting_for, final_state) do
    if waiting_for.timer_ref do
      :timer.cancel(waiting_for.timer_ref)
    end

    GenServer.reply(waiting_for.from, final_state)
    {:noreply, %{final_state | waiting_for: nil}}
  end

  # Tries to handle an event from the buffer
  defp try_handle_event_from_buffer(event_types, state) do
    buffer = Map.get(state, :event_buffer, EventBuffer.new())

    case EventBuffer.find_and_remove(buffer, event_types) do
      {:found, event_type, data, _timestamp, new_buffer} ->
        updated_state = %{state | event_buffer: new_buffer}
        step_config = Orchestrator.get_current_step_config(state)

        # Call handle_event and capture both the updated state AND the diff
        {final_state, diff} =
          StepUtils.call_step_function_with_diff(
            step_config.type,
            :handle_event,
            [event_type, data],
            updated_state
          )

        # Fire context_changed event with the actual diff that was applied
        if diff != [] do
          EventRecorder.record_event(final_state, "context_changed", %{
            context_diff: diff
          })
        end

        {:found, final_state}

      :not_found ->
        :not_found
    end
  end
end
