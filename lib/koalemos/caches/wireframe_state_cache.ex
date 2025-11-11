defmodule Koalemos.Caches.WireframeStateCache do
  @moduledoc """
  Simple ETS-based cache for storing wireframe lens_state by routine_id.

  Used to pass lens_state from WireframeTestLive to WireframePreviewLive
  when the preview iframe first mounts.
  """
  use GenServer
  require Logger

  @table :wireframe_state_cache

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Store lens_state for a routine.
  """
  def put_state(routine_id, lens_state) do
    :ets.insert(@table, {routine_id, lens_state, System.monotonic_time(:second)})
    :ok
  end

  @doc """
  Get lens_state for a routine.
  """
  def get_state(routine_id) do
    case :ets.lookup(@table, routine_id) do
      [{^routine_id, lens_state, _timestamp}] -> lens_state
      [] -> nil
    end
  end

  @doc """
  Delete lens_state for a routine.
  """
  def delete_state(routine_id) do
    :ets.delete(@table, routine_id)
    :ok
  end

  # Server Callbacks

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])

    # Schedule periodic cleanup (every 5 minutes)
    schedule_cleanup()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  # Private Helpers

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.minutes(5))
  end

  defp cleanup_old_entries do
    # Remove entries older than 1 hour
    now = System.monotonic_time(:second)
    cutoff = now - 3600

    :ets.select_delete(@table, [
      {{:"$1", :"$2", :"$3"}, [{:<, :"$3", cutoff}], [true]}
    ])
  end
end
