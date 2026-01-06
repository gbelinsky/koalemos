defmodule WireframeEditorWeb.Servers.WireframeStateServer.PreviewCoordinator do
  @moduledoc """
  Preview lifecycle management and coordination.

  Handles:
  - Preview registration and monitoring
  - Request queuing when preview not ready
  - Blocking capture_state and execute_interaction
  - Reload signaling

  ## Two-State Model

  - preview_pid == nil: Not ready, queue requests
  - preview_pid == pid: Ready, process requests

  ## Message Protocol

  Outgoing (to PreviewLive):
  - {:capture_state, coordinator_pid, from}
  - {:execute_interaction, coordinator_pid, from, args}
  - :reload_preview

  Incoming (from PreviewLive):
  - {:state_captured, from, payload}
  - {:interaction_complete, from, result}
  """

  use GenServer
  require Logger
  require Koalemos.Log
  alias Koalemos.Log

  alias WireframeEditorWeb.Servers.WireframeStateServer.StateStore

  @registry Koalemos.WireframeRegistry
  @default_timeout 10_000

  # ============================================================================
  # Client API
  # ============================================================================

  def start_link(opts) do
    routine_id = Keyword.fetch!(opts, :routine_id)
    GenServer.start_link(__MODULE__, routine_id, name: via_tuple(routine_id))
  end

  @doc "Check if a coordinator exists for this routine"
  def exists?(routine_id) do
    case Registry.lookup(@registry, {:coordinator, routine_id}) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @doc """
  Register a preview process. Called by PreviewLive on "preview_ready" event.
  Monitors the preview pid and flushes any pending requests.
  """
  def register_preview(routine_id, preview_pid) do
    call(routine_id, {:register_preview, preview_pid})
  end

  @doc """
  Capture the current state from the preview. Blocks until complete.
  Returns {:ok, state} or {:error, reason}
  """
  def capture_state(routine_id, timeout \\ @default_timeout) do
    call(routine_id, {:capture_state, timeout}, timeout + 1000)
  end

  @doc """
  Execute an interaction in the preview. Blocks until complete.
  Returns {:ok, result} or {:error, reason}
  """
  def execute_interaction(routine_id, args, timeout \\ @default_timeout) do
    call(routine_id, {:execute_interaction, args, timeout}, timeout + 1000)
  end

  @doc """
  Tell the preview to reload from designed state.
  Non-blocking - preview will die and respawn.
  """
  def reload_preview(routine_id) do
    call(routine_id, :reload_preview)
  end

  @doc "Check if preview is currently registered and ready"
  def preview_ready?(routine_id) do
    call(routine_id, :preview_ready?)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(routine_id) do

    state = %{
      routine_id: routine_id,
      preview_pid: nil,
      preview_ref: nil,
      pending: :queue.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:register_preview, preview_pid}, _from, state) do
    Log.debug(:wireframe, "[PreviewCoordinator] Registering preview: #{inspect(preview_pid)}")

    # Clean up old monitor if exists
    if state.preview_ref do
      Process.demonitor(state.preview_ref, [:flush])
    end

    # Monitor new preview
    ref = Process.monitor(preview_pid)

    # Flush pending queue
    state = flush_pending(%{state | preview_pid: preview_pid, preview_ref: ref})

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:capture_state, timeout}, from, state) do
    request = {:capture_state, from, timeout}
    state = enqueue_or_process(request, state)
    {:noreply, state}
  end

  @impl true
  def handle_call({:execute_interaction, args, timeout}, from, state) do
    request = {:execute_interaction, from, args, timeout}
    state = enqueue_or_process(request, state)
    {:noreply, state}
  end

  @impl true
  def handle_call(:reload_preview, _from, state) do
    if state.preview_pid do
      Log.debug(:wireframe, "[PreviewCoordinator] Sending reload to preview")
      send(state.preview_pid, :reload_preview)
    else
      Logger.warning("[PreviewCoordinator] No preview to reload")
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:preview_ready?, _from, state) do
    {:reply, state.preview_pid != nil, state}
  end

  # Handle responses from PreviewLive
  @impl true
  def handle_info({:state_captured, from, payload}, state) do
    Log.debug(:wireframe, "[PreviewCoordinator] State captured, replying to #{inspect(from)}")

    # Store running state
    StateStore.update_running(state.routine_id, payload)

    # Reply to waiting caller
    GenServer.reply(from, {:ok, payload})

    {:noreply, state}
  end

  @impl true
  def handle_info({:interaction_complete, from, result}, state) do
    Log.debug(:wireframe, "[PreviewCoordinator] Interaction complete, replying to #{inspect(from)}")

    GenServer.reply(from, {:ok, result})

    {:noreply, state}
  end

  # Handle preview death
  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, %{preview_ref: ref} = state) do
    Log.debug(:wireframe, "[PreviewCoordinator] Preview died: #{inspect(pid)}, reason: #{inspect(reason)}")

    # Fail all pending requests
    state = fail_pending(state, {:error, :preview_died})

    {:noreply, %{state | preview_pid: nil, preview_ref: nil}}
  end

  @impl true
  def handle_info(msg, state) do
    Log.debug(:wireframe, "[PreviewCoordinator] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ============================================================================
  # Private
  # ============================================================================

  defp via_tuple(routine_id) do
    {:via, Registry, {@registry, {:coordinator, routine_id}}}
  end

  defp call(routine_id, message, timeout \\ 5000) do
    case Registry.lookup(@registry, {:coordinator, routine_id}) do
      [{pid, _}] -> GenServer.call(pid, message, timeout)
      [] -> {:error, :not_found}
    end
  end

  defp enqueue_or_process(request, %{preview_pid: nil} = state) do
    Log.debug(:wireframe, "[PreviewCoordinator] No preview, queuing request")
    %{state | pending: :queue.in(request, state.pending)}
  end

  defp enqueue_or_process(request, state) do
    process_request(request, state)
    state
  end

  defp process_request({:capture_state, from, _timeout}, state) do
    Log.debug(:wireframe, "[PreviewCoordinator] Sending capture_state to preview")
    send(state.preview_pid, {:capture_state, self(), from})
  end

  defp process_request({:execute_interaction, from, args, _timeout}, state) do
    Log.debug(:wireframe, "[PreviewCoordinator] Sending execute_interaction to preview")
    send(state.preview_pid, {:execute_interaction, self(), from, args})
  end

  defp flush_pending(state) do
    case :queue.out(state.pending) do
      {:empty, _} ->
        state

      {{:value, request}, remaining} ->
        process_request(request, state)
        flush_pending(%{state | pending: remaining})
    end
  end

  defp fail_pending(state, error) do
    case :queue.out(state.pending) do
      {:empty, _} ->
        state

      {{:value, request}, remaining} ->
        from = get_from(request)
        GenServer.reply(from, error)
        fail_pending(%{state | pending: remaining}, error)
    end
  end

  defp get_from({:capture_state, from, _timeout}), do: from
  defp get_from({:execute_interaction, from, _args, _timeout}), do: from
end
