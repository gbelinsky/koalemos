defmodule KoalemosWeb.Servers.WireframeStateServerV4.StateStore do
  @moduledoc """
  Pure state GenServer for wireframe data storage.

  Handles:
  - designed: DOM tree, handlers, init scripts, custom CSS/functions/variables
  - running: Live DOM tree, variables, console logs (captured from preview)
  - screenshot: Base64 encoded PNG

  No external dependencies - just state storage with get/update operations.
  Registered via Registry with routine_id for direct lookup.
  """

  use GenServer
  require Logger

  @registry Koalemos.WireframeV4Registry

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts) do
    routine_id = Keyword.fetch!(opts, :routine_id)
    designed = Keyword.get(opts, :designed, %{})

    GenServer.start_link(__MODULE__, {routine_id, designed}, name: via_tuple(routine_id))
  end

  @doc "Check if a state store exists for this routine"
  def exists?(routine_id) do
    case Registry.lookup(@registry, {:state_store, routine_id}) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @doc "Get the designed state"
  def get_designed(routine_id) do
    call(routine_id, :get_designed)
  end

  @doc "Get the running state (captured from live preview)"
  def get_running(routine_id) do
    call(routine_id, :get_running)
  end

  @doc "Get the screenshot"
  def get_screenshot(routine_id) do
    call(routine_id, :get_screenshot)
  end

  @doc "Update designed state (merge)"
  def update_designed(routine_id, updates) when is_map(updates) do
    call(routine_id, {:update_designed, updates})
  end

  @doc "Update running state (replace)"
  def update_running(routine_id, running) when is_map(running) do
    call(routine_id, {:update_running, running})
  end

  @doc "Update screenshot"
  def update_screenshot(routine_id, screenshot) do
    call(routine_id, {:update_screenshot, screenshot})
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init({routine_id, designed}) do
    Logger.info("[StateStore] Starting for routine: #{routine_id}")

    state = %{
      routine_id: routine_id,
      designed: designed,
      running: nil,
      screenshot: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_designed, _from, state) do
    {:reply, state.designed, state}
  end

  @impl true
  def handle_call(:get_running, _from, state) do
    {:reply, state.running, state}
  end

  @impl true
  def handle_call(:get_screenshot, _from, state) do
    {:reply, state.screenshot, state}
  end

  @impl true
  def handle_call({:update_designed, updates}, _from, state) do
    new_designed = Map.merge(state.designed, updates)
    {:reply, :ok, %{state | designed: new_designed}}
  end

  @impl true
  def handle_call({:update_running, running}, _from, state) do
    {:reply, :ok, %{state | running: running}}
  end

  @impl true
  def handle_call({:update_screenshot, screenshot}, _from, state) do
    {:reply, :ok, %{state | screenshot: screenshot}}
  end

  # ============================================================================
  # Private
  # ============================================================================

  defp via_tuple(routine_id) do
    {:via, Registry, {@registry, {:state_store, routine_id}}}
  end

  defp call(routine_id, message) do
    case Registry.lookup(@registry, {:state_store, routine_id}) do
      [{pid, _}] -> GenServer.call(pid, message)
      [] -> nil
    end
  end
end
