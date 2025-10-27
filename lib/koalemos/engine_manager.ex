defmodule Koalemos.EngineManager do
  @moduledoc """
  Convenience API for managing routine processes.

  EngineManager provides a clean interface for working with Engine processes
  without directly dealing with the Registry or GenServer APIs. It's just a
  collection of helper functions - **not a GenServer or process itself**.

  ## Responsibilities

  - Start/stop routines via Engine
  - List all active routines from Registry
  - Get routine information (state, status, context)
  - Query routine state for debugging

  ## Usage

      # Start a routine
      {:ok, pid} = EngineManager.start_routine(
        "routine-123",
        MyRoutine,
        %{user: "alice"}
      )

      # List all routines
      routines = EngineManager.list_routines()

      # Get specific routine info
      {:ok, info} = EngineManager.get_routine("routine-123")
      info.status  # => :running
      info.current_step  # => :processing

      # Stop a routine
      :ok = EngineManager.stop_routine("routine-123")

  ## RoutineInfo Struct

  The `get_routine/1` function returns a RoutineInfo struct with:

  - `id` - Routine ID (string)
  - `module` - Routine module (atom)
  - `pid` - Process PID
  - `status` - Routine status (`:running`, `:completed`, `:error`)
  - `current_step` - Current step (atom)
  - `started_at` - Start timestamp (currently always `nil` - TODO)
  - `context` - Routine context (map)
  - `execution_stack` - Sub-routine stack (list)
  - `messages` - Messages from context (list)
  - `lens_state` - Lens state from context (map)
  """

  alias Koalemos.Engine

  defmodule RoutineInfo do
    @moduledoc """
    Struct containing routine metadata extracted from Registry and GenServer state.
    """
    defstruct [
      :id,
      :module,
      :pid,
      :status,
      :current_step,
      :started_at,
      :context,
      :execution_stack,
      :messages,
      :lens_state
    ]

    @type t :: %__MODULE__{
            id: String.t(),
            module: atom(),
            pid: pid(),
            status: atom(),
            current_step: atom(),
            started_at: DateTime.t() | nil,
            context: map(),
            execution_stack: list(),
            messages: list(),
            lens_state: map()
          }
  end

  @doc """
  Start a new routine using the Engine.

  This is a convenience wrapper around `Engine.start/1`.

  ## Parameters

  - `routine_id` - Unique routine identifier (string)
  - `routine_module` - The routine module (atom)
  - `initial_context` - Initial context map (default: `%{}`)

  ## Returns

  - `{:ok, pid}` - Success, returns Engine process PID
  - `{:error, term}` - Failure

  ## Examples

      {:ok, pid} = EngineManager.start_routine(
        "routine-123",
        MyRoutine,
        %{user: "alice"}
      )

      # Start with defaults
      {:ok, pid} = EngineManager.start_routine("routine-456", SimpleRoutine)
  """
  @spec start_routine(String.t(), atom(), map()) :: {:ok, pid()} | {:error, term()}
  def start_routine(routine_id, routine_module, initial_context \\ %{}) do
    opts = [
      routine_module: routine_module,
      routine_id: routine_id,
      initial_context: initial_context,
      auto_execute: true
    ]

    case Engine.start(opts) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  @doc """
  Stop a running routine.

  Terminates the Engine process for the given routine ID.

  ## Parameters

  - `routine_id` - The routine ID (string)

  ## Returns

  - `:ok` - Success
  - `{:error, :not_found}` - Routine not found

  ## Examples

      :ok = EngineManager.stop_routine("routine-123")
  """
  @spec stop_routine(String.t()) :: :ok | {:error, :not_found}
  def stop_routine(routine_id) do
    case Registry.lookup(Koalemos.RoutineRegistry, routine_id) do
      [] -> {:error, :not_found}
      [{pid, _value}] ->
        Process.exit(pid, :normal)
        :ok
    end
  end

  @doc """
  Get all active routines from the Registry.

  Returns a list of RoutineInfo structs for all running routines.

  ## Returns

  List of `RoutineInfo.t()`

  ## Examples

      routines = EngineManager.list_routines()
      Enum.each(routines, fn info ->
        IO.puts("\#{info.id}: \#{info.status}")
      end)
  """
  @spec list_routines() :: [RoutineInfo.t()]
  def list_routines do
    Koalemos.RoutineRegistry
    |> Registry.select([{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
    |> Enum.map(fn {routine_id, pid, _value} ->
      build_routine_info(routine_id, pid)
    end)
    |> Enum.filter(& &1)  # Remove any nil results
  end

  @doc """
  Get detailed information about a specific routine.

  Returns a RoutineInfo struct with the routine's current state.

  ## Parameters

  - `routine_id` - The routine ID (string)

  ## Returns

  - `{:ok, RoutineInfo.t()}` - Success
  - `{:error, :not_found}` - Routine not found

  ## Examples

      {:ok, info} = EngineManager.get_routine("routine-123")
      info.status  # => :running
      info.context  # => %{user: "alice", ...}
  """
  @spec get_routine(String.t()) :: {:ok, RoutineInfo.t()} | {:error, :not_found}
  def get_routine(routine_id) do
    case Registry.lookup(Koalemos.RoutineRegistry, routine_id) do
      [] -> {:error, :not_found}
      [{pid, _value}] ->
        case build_routine_info(routine_id, pid) do
          nil -> {:error, :not_found}
          routine_info -> {:ok, routine_info}
        end
    end
  end

  @doc """
  Get the current state from a routine GenServer.

  This is a low-level function for debugging. Use `get_routine/1` for
  structured information.

  ## Parameters

  - `routine_id` - The routine ID (string)

  ## Returns

  - `{:ok, map}` - Success, returns raw state
  - `{:error, term}` - Failure (`:not_found` or exit reason)

  ## Examples

      {:ok, state} = EngineManager.get_routine_state("routine-123")
      state.routine_status  # => :running
      state.event_buffer  # => %EventBuffer{...}
  """
  @spec get_routine_state(String.t()) :: {:ok, map()} | {:error, term()}
  def get_routine_state(routine_id) do
    case Registry.lookup(Koalemos.RoutineRegistry, routine_id) do
      [] -> {:error, :not_found}
      [{pid, _value}] ->
        try do
          state = :sys.get_state(pid)
          {:ok, state}
        catch
          :exit, reason -> {:error, reason}
        end
    end
  end

  # Private functions

  defp build_routine_info(routine_id, pid) do
    try do
      state = :sys.get_state(pid)

      %RoutineInfo{
        id: routine_id,
        module: state.module,
        pid: pid,
        status: Map.get(state, :routine_status, :unknown),
        current_step: Map.get(state, :current_step, :unknown),
        started_at: extract_started_at(state),
        context: Map.get(state, :context, %{}),
        execution_stack: Map.get(state, :execution_stack, []),
        messages: extract_messages(state),
        lens_state: extract_lens_state(state)
      }
    catch
      :exit, _reason -> nil
    end
  end

  defp extract_started_at(_state) do
    # TODO: Extract from event buffer or add to state tracking
    # For now, return nil - could be enhanced later
    nil
  end

  defp extract_messages(state) do
    # Try to extract messages from context
    context = Map.get(state, :context, %{})
    Map.get(context, :messages, [])
  end

  defp extract_lens_state(state) do
    # Try to extract lens state from context
    context = Map.get(state, :context, %{})
    Map.get(context, :lens_state, %{})
  end
end
