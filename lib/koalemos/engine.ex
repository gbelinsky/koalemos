defmodule Koalemos.Engine do
  @moduledoc """
  Main GenServer for routine execution.

  The Engine is the top-level process that manages a single routine's execution.
  It delegates to specialized modules for different concerns:
  - **Orchestrator** - Step execution and transitions
  - **EventHandler** - External events and waiting logic

  ## Process Lifecycle

  1. **Start** - `Engine.start/1` or `Engine.start_link/1`
  2. **Init** - Load routine definition, initialize state, record routine_started
  3. **Execution** - Handle messages, delegate to Orchestrator/EventHandler
  4. **Completion** - Routine reaches :end or :error state

  ## Registry Integration

  Each Engine process registers with `Koalemos.RoutineRegistry` using its routine_id:

      {:via, Registry, {Koalemos.RoutineRegistry, routine_id}}

  This allows looking up routines by ID and sending them messages.

  ## Message Handling

  The Engine receives and routes three types of messages:

  ### Info Messages (async):
  - `:continue_routine` → Orchestrator.execute_current_step
  - `{:event, :step_complete, result}` → Orchestrator.handle_step_success/error
  - `{:external_event, :timeout, types}` → EventHandler.handle_timeout_event

  ### Call Messages (sync):
  - `{:get_event, types, timeout, diff}` → EventHandler.handle_get_event

  ### Cast Messages (async):
  - `{:external_event, type, data}` → EventHandler.handle_external_event

  ## State Structure

  The engine state contains:

  ```elixir
  %{
    routine_id: "routine-123",              # Unique ID
    module: MyRoutine,                      # Root routine module
    routine_definitions: %{...},            # Loaded routine definitions
    current_routine_module: MyRoutine,      # Current routine (changes with sub-routines)
    current_step: :init,                    # Current step
    context: %{...},                        # Routine context (data)
    routine_status: :running,               # :running | :completed | :error
    auto_execute: true,                     # Auto-transition or wait for :continue_routine
    event_buffer: %EventBuffer{},           # Buffered external events
    waiting_for: nil | %{...},              # Waiting state for events
    execution_stack: []                     # Stack for sub-routine calls
  }
  ```

  ## Usage

      # Start a routine
      {:ok, pid} = Engine.start(
        routine_module: MyRoutine,
        routine_id: "routine-123",
        initial_context: %{user: "alice"},
        auto_execute: true
      )

      # Send external event
      Engine.send_external_event("routine-123", :user_input, "hello")

      # Wait for event (called by step)
      Engine.handle_event([:user_input], 5000, [], "routine-123")
  """

  use GenServer
  require Logger

  alias Koalemos.Engine.{EventRecorder, EventHandler, Orchestrator, StepUtils, EventBuffer}
  require Koalemos.Engine.StepUtils

  @type routine_id :: String.t()
  @type routine_module :: module()
  @type initial_context :: map()
  @type auto_execute :: boolean()
  @type start_opts :: [
          routine_module: routine_module(),
          routine_id: routine_id(),
          initial_context: initial_context(),
          auto_execute: auto_execute()
        ]

  # Public API

  @doc """
  Starts an Engine process with supervision link.

  ## Options

  - `:routine_module` - The routine module (required)
  - `:routine_id` - Unique routine identifier (required)
  - `:initial_context` - Initial context map (default: `%{}`)
  - `:auto_execute` - Auto-execute steps (default: `true`)

  ## Examples

      {:ok, pid} = Engine.start_link(
        routine_module: MyRoutine,
        routine_id: "routine-123",
        initial_context: %{user: "alice"}
      )
  """
  @spec start_link(start_opts()) :: GenServer.on_start()
  def start_link(opts) do
    do_start(:start_link, opts)
  end

  @doc """
  Starts an Engine process without supervision link.

  Same options as `start_link/1`.
  """
  @spec start(start_opts()) :: GenServer.on_start()
  def start(opts) do
    do_start(:start, opts)
  end

  @doc """
  Waits for specific event types with optional timeout.

  Called by steps that need to wait for external events (e.g., user input).
  This is a synchronous call that blocks until an event arrives or timeout expires.

  ## Parameters

  - `event_types` - List of event types to wait for
  - `timeout` - Timeout in milliseconds, `nil` for infinite, `0` for immediate
  - `diff` - Context diff to apply before waiting
  - `routine_id` - The routine ID

  ## Returns

  Updated state after event is handled

  ## Examples

      # Wait for user input with 30 second timeout
      state = Engine.handle_event([:user_input], 30_000, [], "routine-123")

      # Wait forever
      state = Engine.handle_event([:user_input, :cancel], nil, [], "routine-123")

      # Check if event exists without waiting
      state = Engine.handle_event([:user_input], 0, [], "routine-123")
  """
  @spec handle_event(list(atom()), non_neg_integer() | nil, list(), routine_id()) :: map()
  def handle_event(event_types, timeout, diff, routine_id) do
    GenServer.call(
      {:via, Registry, {Koalemos.RoutineRegistry, routine_id}},
      {:get_event, event_types, timeout, diff},
      :infinity
    )
  end

  @doc """
  Sends an external event to a routine.

  This is an asynchronous cast - it returns immediately. The event will be
  buffered and matched against waiting steps.

  ## Parameters

  - `routine_id` - The routine ID
  - `event_type` - The type of event (atom)
  - `data` - The event data (any term)

  ## Examples

      # Send user input
      Engine.send_external_event("routine-123", :user_input, "hello world")

      # Send HTTP response
      Engine.send_external_event("routine-123", :http_response, %{status: 200, body: "..."})
  """
  @spec send_external_event(routine_id(), atom(), term()) :: :ok
  def send_external_event(routine_id, event_type, data) do
    GenServer.cast(
      {:via, Registry, {Koalemos.RoutineRegistry, routine_id}},
      {:external_event, event_type, data}
    )
  end

  # GenServer callbacks

  defp do_start(link_type, opts) do
    routine_module = Keyword.fetch!(opts, :routine_module)
    routine_id = Keyword.fetch!(opts, :routine_id)
    initial_context = Keyword.get(opts, :initial_context, %{})
    auto_execute = Keyword.get(opts, :auto_execute, true)

    apply(GenServer, link_type, [
      __MODULE__,
      {routine_module, routine_id, initial_context, auto_execute},
      [name: {:via, Registry, {Koalemos.RoutineRegistry, routine_id}}]
    ])
  end

  @impl true
  def init({routine_module, routine_id, initial_context, auto_execute}) do
    try do
      initial_definition = routine_module.routine_definition()

      # Auto-call routine's initial_context/0 if it exists
      default_context = StepUtils.safe_call(routine_module, :initial_context, []) || %{}

      # User-provided context overrides defaults
      merged_context = Map.merge(default_context, initial_context)

      state = %{
        routine_id: routine_id,
        module: routine_module,
        routine_definitions: %{routine_module => initial_definition},
        current_routine_module: routine_module,
        current_step: StepUtils.safe_call(routine_module, :start, []) || :start,
        context: merged_context,
        routine_status: :running,
        auto_execute: auto_execute,
        event_buffer: EventBuffer.new(),
        waiting_for: nil,
        execution_stack: []
      }

      routine_config = merged_context[:routine_config] || %{}

      state_after_setup =
        StepUtils.call_step_function_if_exists(routine_module, :setup, [routine_config], state)

      # Record routine start event
      EventRecorder.record_routine_started(
        routine_id,
        routine_module,
        initial_context,
        auto_execute
      )

      if auto_execute do
        send(self(), :continue_routine)
      end

      {:ok, state_after_setup}
    rescue
      UndefinedFunctionError ->
        Logger.error(
          "Init failed: Routine module #{routine_module} must implement routine_definition/0"
        )

        {:stop, {:error, "Routine module #{routine_module} must implement routine_definition/0"}}

      error ->
        Logger.error("Init failed: #{Exception.message(error)}")

        {:stop,
         {:error, "Failed to initialize routine #{routine_id}: #{Exception.message(error)}"}}
    end
  end

  @impl true
  def handle_call({:get_event, event_types, timeout, diff}, from, state) do
    EventHandler.handle_get_event(event_types, timeout, diff, from, state)
  end

  @impl true
  def handle_cast({:external_event, event_type, data}, state) do
    EventHandler.handle_external_event(event_type, data, state)
  end

  @impl true
  def handle_info({:external_event, :timeout, original_event_types}, state) do
    EventHandler.handle_timeout_event(original_event_types, state)
  end

  @impl true
  def handle_info(:continue_routine, state) do
    updated_state = Orchestrator.execute_current_step(state)
    {:noreply, updated_state}
  end

  @impl true
  def handle_info({:event, :step_complete, {:ok, diff}}, state) do
    Orchestrator.handle_step_success(diff, state)
  end

  @impl true
  def handle_info({:event, :step_complete, {:error, reason}}, state) do
    Orchestrator.handle_step_error(reason, state)
  end
end
