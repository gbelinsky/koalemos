defmodule Koalemos.Caches.VariableStateCache do
  @moduledoc """
  GenServer for storing runtime variable state from wireframe previews.

  Stores the current runtime values of global JavaScript variables (`window.*`)
  for each routine, allowing agents to see how their variables change during execution.

  This separates design-time initial values (from JavaScriptParser) from runtime
  current values (stored in this cache).

  ## Usage

      alias Koalemos.Caches.VariableStateCache

      # Store variable state
      variables = %{"count" => 42, "userName" => "Alice"}
      VariableStateCache.add_variable_state("routine-123", variables)

      # Retrieve just the variables
      variables = VariableStateCache.get_variable_state("routine-123")
      # => %{"count" => 42, "userName" => "Alice"}

      # Retrieve variables with metadata
      entry = VariableStateCache.get_variable_state_with_metadata("routine-123")
      # => %{variables: ..., timestamp: ..., cached_at: ...}

      # Clear variable state
      VariableStateCache.clear_variable_state("routine-123")

      # Clear all variable states (useful for testing)
      VariableStateCache.clear_all()

  ## Storage Format

  Variable states are stored as:
  ```
  %{
    routine_id => %{
      variables: %{"varName" => value, ...},
      timestamp: integer,
      cached_at: DateTime
    }
  }
  ```
  """

  use GenServer
  require Logger

  # Client API

  @doc """
  Start the VariableStateCache GenServer.

  Registered as a named process for easy access throughout the application.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Add or update the runtime variable state for a routine.

  ## Parameters

  - `routine_id` - The routine identifier (string)
  - `variables` - Map of variable names to values

  ## Returns

  `:ok`

  ## Examples

      iex> variables = %{"count" => 10, "name" => "test"}
      iex> VariableStateCache.add_variable_state("routine-123", variables)
      :ok
  """
  @spec add_variable_state(String.t(), map()) :: :ok
  def add_variable_state(routine_id, variables)
      when is_binary(routine_id) and is_map(variables) do
    GenServer.cast(__MODULE__, {:add_variable_state, routine_id, variables})
  end

  @doc """
  Get the current runtime variable state for a routine.

  Returns just the variables map (not the metadata).

  ## Parameters

  - `routine_id` - The routine identifier (string)

  ## Returns

  - Variables map if exists
  - `nil` if no variable state for this routine

  ## Examples

      iex> variables = %{"count" => 5}
      iex> VariableStateCache.add_variable_state("routine-123", variables)
      iex> VariableStateCache.get_variable_state("routine-123")
      %{"count" => 5}

      iex> VariableStateCache.get_variable_state("nonexistent")
      nil
  """
  @spec get_variable_state(String.t()) :: map() | nil
  def get_variable_state(routine_id) when is_binary(routine_id) do
    GenServer.call(__MODULE__, {:get_variable_state, routine_id})
  end

  @doc """
  Get the full variable state entry including metadata.

  Returns the complete entry with variables, timestamp, and cached_at.

  ## Parameters

  - `routine_id` - The routine identifier (string)

  ## Returns

  - Map with `:variables`, `:timestamp`, `:cached_at` if exists
  - `nil` if no variable state for this routine

  ## Examples

      iex> variables = %{"x" => 1}
      iex> VariableStateCache.add_variable_state("routine-123", variables)
      iex> entry = VariableStateCache.get_variable_state_with_metadata("routine-123")
      iex> entry.variables
      %{"x" => 1}
      iex> is_integer(entry.timestamp)
      true
  """
  @spec get_variable_state_with_metadata(String.t()) :: map() | nil
  def get_variable_state_with_metadata(routine_id) when is_binary(routine_id) do
    GenServer.call(__MODULE__, {:get_variable_state_with_metadata, routine_id})
  end

  @doc """
  Clear the variable state for a given routine.

  ## Parameters

  - `routine_id` - The routine identifier (string)

  ## Returns

  `:ok` (always succeeds, even if no variable state exists)

  ## Examples

      iex> VariableStateCache.clear_variable_state("routine-123")
      :ok
  """
  @spec clear_variable_state(String.t()) :: :ok
  def clear_variable_state(routine_id) when is_binary(routine_id) do
    GenServer.cast(__MODULE__, {:clear_variable_state, routine_id})
  end

  @doc """
  Clear all variable states.

  Useful for testing or manual cleanup.

  ## Returns

  `:ok`

  ## Examples

      iex> VariableStateCache.clear_all()
      :ok
  """
  @spec clear_all() :: :ok
  def clear_all do
    GenServer.cast(__MODULE__, :clear_all)
  end

  @doc """
  Get statistics about the variable state cache.

  ## Returns

  Map with cache statistics:
  - `total_routines` - Number of routines with cached variable states

  ## Examples

      iex> VariableStateCache.get_stats()
      %{total_routines: 0}
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    Logger.info("[VariableStateCache] Starting")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:add_variable_state, routine_id, variables}, state) do
    variable_state = %{
      variables: variables,
      timestamp: System.system_time(:millisecond),
      cached_at: DateTime.utc_now()
    }

    new_state = Map.put(state, routine_id, variable_state)
    Logger.debug("[VariableStateCache] Stored variable state for routine #{routine_id}")

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:clear_variable_state, routine_id}, state) do
    new_state = Map.delete(state, routine_id)
    Logger.debug("[VariableStateCache] Cleared variable state for routine #{routine_id}")

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:clear_all, _state) do
    Logger.debug("[VariableStateCache] Cleared all variable states")
    {:noreply, %{}}
  end

  @impl true
  def handle_call({:get_variable_state, routine_id}, _from, state) do
    variables =
      case Map.get(state, routine_id) do
        nil -> nil
        variable_state -> variable_state.variables
      end

    {:reply, variables, state}
  end

  @impl true
  def handle_call({:get_variable_state_with_metadata, routine_id}, _from, state) do
    variable_state = Map.get(state, routine_id)
    {:reply, variable_state, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      total_routines: map_size(state)
    }

    {:reply, stats, state}
  end
end
