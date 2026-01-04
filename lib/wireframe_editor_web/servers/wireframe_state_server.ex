defmodule WireframeEditorWeb.Servers.WireframeStateServer do
  @moduledoc """
  V4 Wireframe State Server - facade module.

  Provides a unified API delegating to two submodules:
  - StateStore: Pure state storage (designed, running, screenshot)
  - PreviewCoordinator: Preview lifecycle and blocking operations

  ## Architecture Simplification (V4 vs V3)

  - No PubSub: Direct process communication via Registry
  - No adapters: Lens calls StateServer directly
  - Two-state preview model: pid == nil (not ready) or pid (ready)
  - Blocking operations: capture_state/execute_interaction return when done

  ## Usage

      # Start both submodules (called from Routine.setup)
      {:ok, _} = WireframeStateServer.start_link(routine_id: "abc", designed: %{...})

      # State operations
      designed = WireframeStateServer.get_designed("abc")
      :ok = WireframeStateServer.update_designed("abc", %{dom_tree: ...})

      # Preview coordination
      :ok = WireframeStateServer.register_preview("abc", preview_pid)
      {:ok, state} = WireframeStateServer.capture_state("abc")
      {:ok, result} = WireframeStateServer.execute_interaction("abc", %{action: "click", ...})
      :ok = WireframeStateServer.reload_preview("abc")
  """

  alias WireframeEditorWeb.Servers.WireframeStateServer.{StateStore, PreviewCoordinator}

  @supervisor WireframeEditorWeb.Supervisors.WireframeStateServerSupervisor

  # ============================================================================
  # Lifecycle
  # ============================================================================

  @doc """
  Start both StateStore and PreviewCoordinator for a routine.
  Called from Routine.setup after parsing HTML.

  Options:
  - :routine_id (required) - Unique identifier for this routine
  - :designed (optional) - Initial designed state (already parsed)
  """
  def start_link(opts) do
    routine_id = Keyword.fetch!(opts, :routine_id)
    designed = Keyword.get(opts, :designed, %{})

    # Start StateStore
    {:ok, _store_pid} =
      DynamicSupervisor.start_child(@supervisor, {StateStore, routine_id: routine_id, designed: designed})

    # Start PreviewCoordinator
    {:ok, coordinator_pid} =
      DynamicSupervisor.start_child(@supervisor, {PreviewCoordinator, routine_id: routine_id})

    {:ok, coordinator_pid}
  end

  @doc "Check if state server exists for this routine"
  def exists?(routine_id) do
    StateStore.exists?(routine_id)
  end

  # ============================================================================
  # State Operations (delegate to StateStore)
  # ============================================================================

  @doc "Get the designed state"
  defdelegate get_designed(routine_id), to: StateStore

  @doc "Get the running state"
  defdelegate get_running(routine_id), to: StateStore

  @doc "Get the screenshot"
  defdelegate get_screenshot(routine_id), to: StateStore

  @doc "Update designed state (merge)"
  defdelegate update_designed(routine_id, updates), to: StateStore

  @doc "Update running state (replace)"
  defdelegate update_running(routine_id, running), to: StateStore

  @doc "Update screenshot"
  defdelegate update_screenshot(routine_id, screenshot), to: StateStore

  @doc "Check if screenshot is needed"
  defdelegate screenshot_needed?(routine_id), to: StateStore

  @doc "Set screenshot_needed flag"
  defdelegate set_screenshot_needed(routine_id, needed), to: StateStore

  # ============================================================================
  # Preview Coordination (delegate to PreviewCoordinator)
  # ============================================================================

  @doc "Register a preview process"
  defdelegate register_preview(routine_id, preview_pid), to: PreviewCoordinator

  @doc "Capture state from preview (blocking)"
  defdelegate capture_state(routine_id), to: PreviewCoordinator

  @doc "Capture state from preview with timeout (blocking)"
  defdelegate capture_state(routine_id, timeout), to: PreviewCoordinator

  @doc "Execute interaction in preview (blocking)"
  defdelegate execute_interaction(routine_id, args), to: PreviewCoordinator

  @doc "Execute interaction in preview with timeout (blocking)"
  defdelegate execute_interaction(routine_id, args, timeout), to: PreviewCoordinator

  @doc "Tell preview to reload from designed state"
  defdelegate reload_preview(routine_id), to: PreviewCoordinator

  @doc "Check if preview is ready"
  defdelegate preview_ready?(routine_id), to: PreviewCoordinator
end
