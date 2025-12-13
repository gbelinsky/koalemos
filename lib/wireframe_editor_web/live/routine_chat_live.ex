defmodule WireframeEditorWeb.RoutineChatLive do
  @moduledoc """
  Main chat interface for a routine session.

  Displays the ChatPanel component and manages the routine lifecycle.

  ## Sprint 6 (Current)
  - Start routine via EngineManager
  - Subscribe to routine events via PubSub
  - Handle real AI messages
  - Display routine status (running, completed, error)
  """
  use WireframeEditorWeb, :live_view
  require Logger

  alias WireframeEditorWeb.{ChatPanel, StartSessionModal, ErrorDisplay}
  alias Koalemos.{EngineManager, Engine}
  alias Koalemos.Routines.TestChatRoutine

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Chat",
       routine_id: nil,
       status: :running,
       messages: [],
       current_step: nil,
       last_error: nil,
       config: %{llm_provider: "anthropic", model: "claude-haiku-4-5"},
       recent_events: [],
       # Only show debug in dev mode (Mix not available in releases)
       show_debug: Code.ensure_loaded?(Mix) and Mix.env() == :dev,
       show_modal: false
     )}
  end

  @impl true
  def handle_params(%{"routine_id" => routine_id} = params, _uri, socket) do
    # Get provider and model from URL query params (defaults if not provided)
    provider = Map.get(params, "provider", "anthropic")
    model = Map.get(params, "model", "claude-haiku-4-5")

    # Subscribe to routine events and load state (only once)
    socket =
      if connected?(socket) && socket.assigns.routine_id == nil do
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")
        # M3 Sprint 3: Subscribe to screenshot requests
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "screenshot:request:#{routine_id}")

        # Try to start the routine (will return existing pid if already running)
        # Engine auto-calls initial_context/0 and merges with user context
        user_context = %{
          llm_provider: provider,
          llm_model: model
        }

        case EngineManager.start_routine(routine_id, TestChatRoutine, user_context) do
          {:ok, _pid} ->
            Logger.info("Started routine #{routine_id} with #{provider}/#{model}")

          {:error, reason} ->
            Logger.error("Failed to start routine #{routine_id}: #{inspect(reason)}")
        end

        # Load existing messages, config, and state if routine was already running
        case EngineManager.get_routine(routine_id) do
          {:ok, routine_info} ->
            Logger.info(
              "Loaded routine state: status=#{routine_info.status}, step=#{inspect(routine_info.current_step)}, messages=#{length(routine_info.messages)}"
            )

            # Extract actual config from routine context
            actual_provider = routine_info.context[:llm_provider] || provider
            actual_model = routine_info.context[:llm_model] || model

            # Extract error from context if present
            error = routine_info.context[:error]

            socket
            |> assign(messages: routine_info.messages)
            |> assign(status: routine_info.status)
            |> assign(current_step: routine_info.current_step)
            |> assign(last_error: error)
            |> assign(
              config: %{
                llm_provider: actual_provider,
                model: actual_model,
                max_tokens: 2000,
                temperature: 0.7
              }
            )

          {:error, _} ->
            # New routine, use URL params
            assign(socket,
              config: %{
                llm_provider: provider,
                model: model,
                max_tokens: 2000,
                temperature: 0.7
              }
            )
        end
      else
        socket
      end

    {:noreply, assign(socket, routine_id: routine_id)}
  end

  @impl true
  def handle_event("open_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: true)}
  end

  @impl true
  def handle_event("screenshot_captured", screenshot_data, socket) do
    # M3 Sprint 3: Handle screenshot data from JavaScript hook
    routine_id = socket.assigns.routine_id
    data = screenshot_data["data"]

    Logger.info(
      "[RoutineChatLive] Screenshot captured for #{routine_id}, #{byte_size(data)} bytes"
    )

    # Broadcast ready notification via PubSub
    Phoenix.PubSub.broadcast(
      Koalemos.PubSub,
      "screenshot:response:#{routine_id}",
      {:screenshot_ready, routine_id}
    )

    Logger.debug("[RoutineChatLive] Broadcast screenshot_ready notification")

    {:noreply, socket}
  end

  @impl true
  def handle_event("screenshot_failed", error_data, socket) do
    # M3 Sprint 3: Handle screenshot capture failure
    error_msg = error_data["error"] || "Unknown error"
    Logger.error("[RoutineChatLive] Screenshot capture failed: #{error_msg}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:close_modal}, socket) do
    {:noreply, assign(socket, show_modal: false)}
  end

  @impl true
  def handle_info(:check_uploads, socket) do
    # Forward to nested UserInputComponent (inside ChatPanel)
    alias WireframeEditorWeb.UserInputComponent
    send_update(UserInputComponent, id: "chat-panel-input", check_uploads: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:clear_sent_feedback, component_id}, socket) do
    # Forward to nested UserInputComponent
    alias WireframeEditorWeb.UserInputComponent
    send_update(UserInputComponent, id: component_id, clear_sent_feedback: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:user_input_submitted,
         %{text: text, images: images, include_screenshot: include_screenshot}},
        socket
      ) do
    Logger.info(
      "User input submitted: text=#{text}, images=#{length(images)}, screenshot=#{include_screenshot}"
    )

    # Send user input to routine
    data = %{text: text, images: images, include_screenshot: include_screenshot}
    Engine.send_external_event(socket.assigns.routine_id, :user_input, data)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_messages, new_messages}, socket) do
    Logger.debug("Received #{length(new_messages)} new message(s)")

    # Append new messages to existing messages
    updated_messages = socket.assigns.messages ++ new_messages

    {:noreply, assign(socket, messages: updated_messages)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "routine_completed"} = event}, socket) do
    Logger.info("Routine completed")

    error = get_in(event, [:metadata, :final_context, :error])

    # If there's an error in the completion, treat it as an error state
    status = if error, do: :error, else: :completed

    socket =
      socket
      |> assign(status: status)
      |> assign(last_error: error)
      |> assign(current_step: nil)
      |> add_event("routine_completed", %{error: error})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "error_occurred"} = event}, socket) do
    error_msg = get_in(event, [:metadata, :reason]) || "Unknown error"
    Logger.error("Routine error: #{error_msg}")

    socket =
      socket
      |> assign(status: :error, last_error: error_msg)
      |> assign(current_step: nil)
      |> add_event("error", %{message: error_msg})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "step_started"} = event}, socket) do
    step = event.step_id
    step_module = get_in(event, [:metadata, :step_module])

    socket =
      socket
      |> assign(current_step: step)
      |> add_event("step_started", %{step: step, module: step_module})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "step_completed"} = event}, socket) do
    step = event.step_id

    socket = add_event(socket, "step_completed", %{step: step})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:screenshot_request, %{routine_id: requested_id}}, socket) do
    # M3 Sprint 3: Handle screenshot capture request from TestLens
    Logger.info("[RoutineChatLive] Screenshot request received for #{requested_id}")

    if socket.assigns.routine_id == requested_id do
      # Trigger screenshot capture via JavaScript hook
      {:noreply, push_event(socket, "trigger_screenshot_capture", %{})}
    else
      Logger.warning(
        "[RoutineChatLive] Screenshot request for wrong routine: #{requested_id} (current: #{socket.assigns.routine_id})"
      )

      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:routine_event, _event}, socket) do
    # Ignore other routine events
    {:noreply, socket}
  end

  defp add_event(socket, event_type, details) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    event = %{type: event_type, details: details, time: timestamp}

    recent = [event | socket.assigns.recent_events] |> Enum.take(20)
    assign(socket, recent_events: recent)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-100">
      <!-- Header -->
      <div class="bg-white border-b border-slate-200 shadow-sm">
        <div class="max-w-6xl mx-auto px-4 py-3 flex items-center justify-between">
          <div class="flex items-center gap-4">
            <a href="/" class="text-slate-600 hover:text-slate-800 transition-colors">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M10 19l-7-7m0 0l7-7m-7 7h18"
                />
              </svg>
            </a>
            <h1 class="text-xl font-semibold text-slate-800">koalemos chat</h1>
            
    <!-- Compact Config Display -->
            <div class="flex items-center gap-3 pl-4 border-l border-slate-200">
              <div class="flex flex-col">
                <div class="text-xs text-slate-500 leading-tight">
                  {@config.llm_provider}
                </div>
                <div class="text-sm font-medium text-slate-700 leading-tight">
                  {@config.model}
                </div>
              </div>
              <button
                phx-click="open_modal"
                class="px-3 py-1.5 text-xs font-medium text-blue-600 hover:text-blue-700 border border-blue-300 hover:border-blue-400 rounded transition-colors"
              >
                New Chat
              </button>
            </div>
          </div>
          <div class="flex items-center gap-3">
            <!-- Status Badge (fixed width) -->
            <div class={[
              "flex items-center gap-2 px-3 py-1 border rounded-full w-28",
              status_class(@status)
            ]}>
              <div class={["w-2 h-2 rounded-full flex-shrink-0", status_dot_class(@status)]}></div>
              <span class={["text-sm flex-1 text-center", status_text_class(@status)]}>
                {status_text(@status)}
              </span>
            </div>
            <!-- Current Step (fixed width) -->
            <%= if @current_step do %>
              <div class="text-xs text-slate-500 font-mono w-32 text-right">
                step: {@current_step}
              </div>
            <% else %>
              <div class="w-32"></div>
            <% end %>
            <!-- Routine ID (small, subtle) -->
            <div class="text-xs text-slate-400 font-mono">
              {@routine_id}
            </div>
          </div>
        </div>
      </div>
      
    <!-- Debug Panel (collapsible) -->
      <%= if @show_debug do %>
        <div class="bg-slate-800 text-white border-b border-slate-700">
          <div class="max-w-6xl mx-auto px-4 py-2">
            <div class="flex items-start justify-between gap-4">
              <!-- Error Display -->
              <%= if @last_error do %>
                <div class="flex-1">
                  <div class="text-xs font-bold text-red-400 mb-1">LAST ERROR</div>
                  <div class="text-xs text-red-300 bg-red-900/30 px-2 py-1 rounded">
                    {@last_error}
                  </div>
                </div>
              <% end %>
              
    <!-- Recent Events -->
              <div class="flex-1">
                <div class="text-xs font-bold text-slate-300 mb-1">RECENT EVENTS</div>
                <div class="text-xs space-y-1 max-h-20 overflow-y-auto">
                  <%= for event <- Enum.take(@recent_events, 5) do %>
                    <div class="flex gap-2">
                      <span class="text-slate-500">{format_time(event.time)}</span>
                      <span class="text-blue-400">{event.type}</span>
                      <%= if event.details[:step] do %>
                        <span class="text-slate-400">→ {event.details.step}</span>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Chat Panel (fills remaining space) -->
      <!-- M3 Sprint 3: ScreenshotCapture hook wraps chat panel -->
      <div
        id="chat-screenshot-target"
        phx-hook="ScreenshotCapture"
        class="flex-1 overflow-hidden"
      >
        <div class="max-w-6xl mx-auto h-full">
          <!-- Error Display -->
          <%= if @last_error do %>
            <div class="px-4 py-4">
              <ErrorDisplay.error_banner error={@last_error} />
            </div>
          <% end %>
          <.live_component
            module={ChatPanel}
            id="chat-panel"
            routine_id={@routine_id}
            messages={@messages}
            mock_responses={false}
            current_step={@current_step}
            disabled={@status in [:completed, :error] || @last_error != nil}
            status={@status}
            last_error={@last_error}
            tool_display={:inline}
            show_system_messages={false}
          />
        </div>
      </div>
      
    <!-- Start Session Modal -->
      <.live_component
        module={StartSessionModal}
        id="start-session-modal"
        show={@show_modal}
      />
    </div>
    """
  end

  # Helper functions

  defp status_text(:ready), do: "ready"
  defp status_text(:running), do: "running"
  defp status_text(:completed), do: "completed"
  defp status_text(:error), do: "error"
  defp status_text(_), do: "unknown"

  defp status_class(:running), do: "bg-blue-50 border-blue-200"
  defp status_class(:completed), do: "bg-gray-50 border-gray-200"
  defp status_class(:error), do: "bg-red-50 border-red-200"
  defp status_class(_), do: "bg-green-50 border-green-200"

  defp status_dot_class(:running), do: "bg-blue-500 animate-pulse"
  defp status_dot_class(:completed), do: "bg-gray-500"
  defp status_dot_class(:error), do: "bg-red-500 animate-pulse"
  defp status_dot_class(_), do: "bg-green-500"

  defp status_text_class(:running), do: "text-blue-700"
  defp status_text_class(:completed), do: "text-gray-700"
  defp status_text_class(:error), do: "text-red-700"
  defp status_text_class(_), do: "text-green-700"

  defp format_time(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%H:%M:%S")
      _ -> "??:??:??"
    end
  end
end
