defmodule Koalemos.Engine.EventRecorder do
  @moduledoc """
  Convenience wrapper for recording routine events via the Observer.

  This module provides a clean interface for engine components to record
  structured events without manually extracting fields from state.

  ## Pattern Note

  This wrapper pattern isn't idiomatic Elixir (see BACKLOG.md "Deferred Improvements"
  for discussion). It exists for historical reasons and works well, but may be
  refactored in the future to have Observer accept state directly or use protocols.

  ## Usage

  Engine components call EventRecorder, which extracts standard fields from the
  engine state and delegates to Observer:

      # In Orchestrator or EventHandler:
      EventRecorder.record_event(state, "step_started", %{
        metadata: %{step: :init}
      })

  This is equivalent to manually calling:

      Observer.record_event(%{
        routine_id: state.routine_id,
        routine_module: state.module,
        event_type: "step_started",
        step_id: state.current_step,
        metadata: %{step: :init}
      })

  ## Event Flow

      Engine Component → EventRecorder → Observer → File & PubSub

  """

  alias Koalemos.Engine.Observer

  @type routine_id :: String.t()
  @type event_type :: String.t()
  @type state :: map()
  @type event_fields :: map()

  @doc """
  Records a routine event with standard fields extracted from state.

  Extracts the following fields from state:
  - `routine_id` - From `state.routine_id` or `state.workflow_id`
  - `routine_module` - From `state.module`
  - `step_id` - From `state.current_step` or `state.current_node`

  Additional fields can be provided and will be merged into the event.

  ## Parameters

  - `state` - The engine state map
  - `event_type` - The type of event (e.g., "step_started", "context_changed")
  - `additional_fields` - Optional map of additional event data

  ## Examples

      # Basic event
      EventRecorder.record_event(state, "step_started")

      # Event with metadata
      EventRecorder.record_event(state, "step_completed", %{
        metadata: %{status: :success}
      })

      # Event with context diff
      EventRecorder.record_event(state, "context_changed", %{
        context_diff: [{:add, %{result: "done"}}]
      })

  """
  @spec record_event(state(), event_type(), event_fields()) :: :ok
  def record_event(state, event_type, additional_fields \\ %{}) do
    # Use Map.get with fallback since || doesn't work with map key access
    routine_id = Map.get(state, :routine_id) || Map.get(state, :workflow_id)
    step_id = Map.get(state, :current_step) || Map.get(state, :current_node)

    base_event = %{
      routine_id: routine_id,
      routine_module: state.module,
      event_type: event_type,
      step_id: step_id
    }

    # Preserve workflow_id for backward compatibility
    base_event =
      case Map.get(state, :workflow_id) do
        nil -> base_event
        workflow_id -> Map.put(base_event, :workflow_id, workflow_id)
      end

    event = Map.merge(base_event, additional_fields)
    Observer.record_event(event)
  end

  @doc """
  Records routine initialization event (special case without full state).

  This is called during `Engine.init/1` before the full state is available.
  It manually constructs the event with the initialization parameters.

  ## Parameters

  - `routine_id` - The routine identifier
  - `routine_module` - The routine module (e.g., `Routines.WireframeDesign`)
  - `initial_context` - The initial context map
  - `auto_execute` - Whether auto-execution is enabled

  ## Examples

      EventRecorder.record_routine_started(
        "routine-123",
        MyApp.Routines.Example,
        %{user: "alice"},
        true
      )

  """
  @spec record_routine_started(routine_id(), module(), map(), boolean()) :: :ok
  def record_routine_started(routine_id, routine_module, initial_context, auto_execute) do
    Observer.record_event(%{
      routine_id: routine_id,
      routine_module: routine_module,
      event_type: "routine_started",
      step_id: :start,
      context_diff: %{add: initial_context},
      metadata: %{auto_execute: auto_execute}
    })
  end
end
