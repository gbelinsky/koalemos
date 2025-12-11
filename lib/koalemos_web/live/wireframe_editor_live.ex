defmodule KoalemosWeb.WireframeEditorLive do
  @moduledoc """
  LiveView page for WireframeEditor with chat + preview layout + debug panels.

  V4 Architecture:
  - No PubSub for wireframe state updates
  - StateServer handles all state coordination
  - Simpler than V3 - just renders iframe and chat panel

  Route: /wireframe-editor-v4/:routine_id
  """

  use KoalemosWeb, :live_view
  require Logger

  alias Koalemos.{EngineManager, Engine}
  alias Koalemos.Routines.WireframeEditorRoutine
  alias KoalemosWeb.ChatPanel
  alias KoalemosWeb.Servers.WireframeStateServer

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Wireframe Editor V4",
       routine_id: nil,
       messages: [],
       status: :idle,
       current_step: nil,
       routine_module: nil,
       execution_stack: [],
       step_module: nil,
       last_error: nil,
       agent_running: false,
       left_panel_width: 40,
       tool_display: :inline,
       show_system_messages: false,
       # Debug panel state
       show_debug: true,
       designed_state: nil,
       running_state: nil,
       screenshot: nil,
       sync_status: nil
     ), layout: false}
  end

  @impl true
  def handle_params(%{"routine_id" => routine_id}, _uri, socket) do
    if connected?(socket) && socket.assigns.routine_id == nil do
      # Subscribe to routine events and messages
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")
      # Note: No wireframe_v4 PubSub subscription needed - StateServer handles coordination

      Logger.info("[WireframeEditorLive] Starting routine #{routine_id}")

      user_context = %{
        routine_id: routine_id,
        llm_provider: "anthropic",
        llm_model: "claude-sonnet-4-5",
        max_tokens: 64000,
        temperature: 0.7
      }

      case EngineManager.start_routine(routine_id, WireframeEditorRoutine, user_context) do
        {:ok, _pid} ->
          Logger.info("[WireframeEditorLive] Routine started successfully")
          Process.send_after(self(), :fetch_initial_state, 500)
          {:noreply,
           assign(socket,
             routine_id: routine_id,
             agent_running: true,
             status: :running
           )}

        {:error, {:already_started, _pid}} ->
          Logger.info("[WireframeEditorLive] Routine already running, connecting")
          Process.send_after(self(), :fetch_initial_state, 100)
          {:noreply,
           assign(socket,
             routine_id: routine_id,
             agent_running: true,
             status: :running
           )}

        {:error, reason} ->
          Logger.error("[WireframeEditorLive] Failed to start routine: #{inspect(reason)}")
          {:noreply, assign(socket, last_error: "Failed to start routine: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # ============================================================================
  # Events
  # ============================================================================

  @impl true
  def handle_event("resize_panel", %{"width" => width_str}, socket) do
    width = String.to_integer(width_str)
    clamped_width = max(25, min(60, width))
    {:noreply, assign(socket, left_panel_width: clamped_width)}
  end

  @impl true
  def handle_event("toggle_debug", _params, socket) do
    new_show_debug = !socket.assigns.show_debug

    # Start auto-refresh when debug panel is shown
    if new_show_debug and socket.assigns.routine_id do
      schedule_debug_refresh()
    end

    {:noreply, assign(socket, show_debug: new_show_debug)}
  end

  @impl true
  def handle_event("refresh_state", _params, socket) do
    routine_id = socket.assigns.routine_id
    Logger.info("[WireframeEditorLive] Manual state refresh requested")

    # Fetch current state from StateServer
    designed = WireframeStateServer.get_designed(routine_id)
    running = WireframeStateServer.get_running(routine_id)
    screenshot = WireframeStateServer.get_screenshot(routine_id)

    {:noreply,
     assign(socket,
       designed_state: designed,
       running_state: running,
       screenshot: screenshot,
       sync_status: "State refreshed"
     )}
  end

  # ============================================================================
  # Info handlers
  # ============================================================================

  @impl true
  def handle_info(:fetch_initial_state, socket) do
    routine_id = socket.assigns.routine_id
    designed = WireframeStateServer.get_designed(routine_id)
    running = WireframeStateServer.get_running(routine_id)
    screenshot = WireframeStateServer.get_screenshot(routine_id)

    # Start auto-refresh timer for debug panel
    if socket.assigns.show_debug do
      schedule_debug_refresh()
    end

    {:noreply,
     assign(socket,
       designed_state: designed,
       running_state: running,
       screenshot: screenshot
     )}
  end

  @impl true
  def handle_info(:refresh_debug_state, socket) do
    if socket.assigns.show_debug and socket.assigns.routine_id do
      routine_id = socket.assigns.routine_id
      designed = WireframeStateServer.get_designed(routine_id)
      running = WireframeStateServer.get_running(routine_id)
      screenshot = WireframeStateServer.get_screenshot(routine_id)

      # Schedule next refresh
      schedule_debug_refresh()

      {:noreply,
       assign(socket,
         designed_state: designed,
         running_state: running,
         screenshot: screenshot
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:check_uploads, socket) do
    send_update(KoalemosWeb.UserInputComponent, id: "v4-chat-panel-input", check_uploads: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:clear_sent_feedback, component_id}, socket) do
    alias KoalemosWeb.UserInputComponent
    send_update(UserInputComponent, id: component_id, clear_sent_feedback: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_input_submitted, %{text: text, images: images} = data}, socket) do
    Logger.info("[WireframeEditorLive] User input: #{String.slice(text, 0, 50)}...")
    include_screenshot = Map.get(data, :include_screenshot, false)

    Engine.send_external_event(socket.assigns.routine_id, :user_input, %{
      text: text,
      images: images,
      include_screenshot: include_screenshot
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_messages, new_messages}, socket) do
    Logger.debug("[WireframeEditorLive] Received #{length(new_messages)} new message(s)")
    updated_messages = socket.assigns.messages ++ new_messages
    {:noreply, assign(socket, messages: updated_messages)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "routine_completed"} = event}, socket) do
    Logger.info("[WireframeEditorLive] Routine completed")
    error = get_in(event, [:metadata, :final_context, :error])
    status = if error, do: :error, else: :completed
    {:noreply, assign(socket, status: status, last_error: error, current_step: nil)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "error_occurred"} = event}, socket) do
    error_msg = get_in(event, [:metadata, :reason]) || "Unknown error"
    Logger.error("[WireframeEditorLive] Routine error: #{error_msg}")
    {:noreply, assign(socket, status: :error, last_error: error_msg, current_step: nil)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "step_started"} = event}, socket) do
    {:noreply,
     assign(socket,
       current_step: event.step_id,
       routine_module: Map.get(event, :routine_module),
       execution_stack: Map.get(event, :execution_stack, []),
       step_module: get_in(event, [:metadata, :step_module])
     )}
  end

  @impl true
  def handle_info({:routine_event, _event}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(message, socket) do
    Logger.debug("[WireframeEditorLive] Unhandled message: #{inspect(message)}")
    {:noreply, socket}
  end

  defp schedule_debug_refresh do
    Process.send_after(self(), :refresh_debug_state, 2000)
  end

  # ============================================================================
  # Render
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-50">
      <!-- Header -->
      <div class="bg-white border-b border-slate-200 shadow-sm flex-shrink-0">
        <div class="px-4 py-2 flex items-center justify-between">
          <div class="flex items-center gap-4">
            <h1 class="text-lg font-semibold text-slate-800">Wireframe Editor V4</h1>
            <span class="text-xs text-slate-500">ID: <%= @routine_id %></span>
            <%= if @sync_status do %>
              <span class="text-xs text-green-600"><%= @sync_status %></span>
            <% end %>
          </div>
          <div class="flex items-center gap-2">
            <button
              phx-click="refresh_state"
              class="px-2 py-1 bg-purple-500 text-white text-xs rounded hover:bg-purple-600"
            >
              Refresh State
            </button>
            <button
              phx-click="toggle_debug"
              class={"px-2 py-1 text-xs rounded #{if @show_debug, do: "bg-amber-500 text-white", else: "bg-gray-200 text-gray-700"}"}
            >
              <%= if @show_debug, do: "Hide Debug", else: "Show Debug" %>
            </button>
            <a
              href={"/wireframe-editor-v4/v4-#{:erlang.unique_integer([:positive])}"}
              class="px-2 py-1 bg-cyan-500 text-white text-xs rounded hover:bg-cyan-600"
            >
              New Session
            </a>
            <a href="/" class="text-xs text-blue-600 hover:text-blue-800">
              Home
            </a>
          </div>
        </div>
      </div>

      <!-- Main Content -->
      <%= if @agent_running && @routine_id do %>
        <div class={"flex-1 overflow-hidden flex flex-col"}>
          <!-- Chat + Preview Row -->
          <div class={"flex overflow-hidden #{if @show_debug, do: "h-1/2", else: "flex-1"}"} id="resizable-container">
            <!-- Left Panel: Chat -->
            <div
              class="border-r border-slate-300 bg-white flex flex-col"
              style={"width: #{@left_panel_width}%"}
            >
              <.live_component
                module={ChatPanel}
                id="v4-chat-panel"
                routine_id={@routine_id}
                messages={@messages}
                mock_responses={false}
                current_step={@current_step}
                routine_module={@routine_module}
                execution_stack={@execution_stack}
                step_module={@step_module}
                disabled={@status in [:completed, :error] || @last_error != nil}
                status={@status}
                last_error={@last_error}
                tool_display={@tool_display}
                show_system_messages={@show_system_messages}
              />
            </div>

            <!-- Resize Handle -->
            <div
              class="w-1 bg-slate-300 hover:bg-blue-500 cursor-col-resize transition-colors flex-shrink-0"
              phx-hook="PanelResizer"
              id="resize-handle"
            >
            </div>

            <!-- Right Panel: V4 Preview -->
            <div class="flex-1 bg-white flex flex-col overflow-hidden">
              <div class="border-b border-slate-200 px-3 py-1 bg-slate-50 flex-shrink-0">
                <span class="text-xs font-medium text-slate-700">Live Preview (V4)</span>
              </div>
              <div class="flex-1 overflow-hidden">
                <iframe
                  src={"/wireframe-preview-v4/#{@routine_id}"}
                  class="w-full h-full border-0"
                  id="wireframe-preview-v4"
                  sandbox="allow-scripts allow-same-origin allow-forms"
                  title="V4 Wireframe Preview"
                >
                </iframe>
              </div>
            </div>
          </div>

          <!-- Debug Panel -->
          <%= if @show_debug do %>
            <div class="h-1/2 border-t border-slate-300 bg-gray-100 overflow-hidden flex flex-col">
              <div class="px-3 py-1 bg-amber-100 border-b border-amber-200 flex-shrink-0">
                <span class="text-xs font-bold text-amber-800">Debug Panel (V4)</span>
              </div>
              <div class="flex-1 overflow-hidden grid grid-cols-3 gap-2 p-2">
                <!-- Designed State -->
                <div class="bg-white rounded shadow overflow-hidden flex flex-col">
                  <div class="px-2 py-1 bg-blue-50 border-b text-xs font-bold text-blue-800 flex-shrink-0">
                    Designed State
                  </div>
                  <pre class="flex-1 text-xs p-2 overflow-auto font-mono"><%= format_state(@designed_state) %></pre>
                </div>

                <!-- Running State -->
                <div class="bg-white rounded shadow overflow-hidden flex flex-col">
                  <div class="px-2 py-1 bg-green-50 border-b text-xs font-bold text-green-800 flex-shrink-0">
                    Running State
                  </div>
                  <%= if @running_state do %>
                    <pre class="flex-1 text-xs p-2 overflow-auto font-mono"><%= format_state(@running_state) %></pre>
                  <% else %>
                    <div class="flex-1 p-2 text-xs text-gray-500">No running state yet</div>
                  <% end %>
                </div>

                <!-- Screenshot -->
                <div class="bg-white rounded shadow overflow-hidden flex flex-col">
                  <div class="px-2 py-1 bg-purple-50 border-b text-xs font-bold text-purple-800 flex-shrink-0">
                    Screenshot
                  </div>
                  <div class="flex-1 p-2 overflow-auto">
                    <%= if @screenshot do %>
                      <img src={"data:image/png;base64,#{@screenshot}"} class="max-w-full border rounded" />
                    <% else %>
                      <div class="text-xs text-gray-500">No screenshot yet</div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <!-- Loading / Not Started -->
        <div class="flex-1 flex items-center justify-center">
          <div class="text-center">
            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500 mx-auto mb-4"></div>
            <p class="text-slate-600">Starting V4 routine...</p>
          </div>
        </div>
      <% end %>

      <!-- Error Display -->
      <%= if @last_error do %>
        <div class="absolute bottom-4 left-4 right-4 max-w-2xl mx-auto z-50">
          <div class="bg-red-50 border border-red-200 rounded-lg p-3 shadow-lg">
            <div class="flex items-start">
              <div class="text-red-600 mr-2">Warning</div>
              <div class="text-sm text-red-800">
                <%= @last_error %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp format_state(nil), do: "nil"
  defp format_state(state) when is_map(state) do
    inspect(state, pretty: true, limit: 500, printable_limit: 2000)
  end
  defp format_state(other), do: inspect(other)
end
