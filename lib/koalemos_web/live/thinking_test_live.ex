defmodule KoalemosWeb.ThinkingTestLive do
  @moduledoc """
  Test page for SequentialThinking lens.

  Interactive chat interface with step-by-step reasoning support.
  Test complex problems and watch the AI break down its thought process.
  """
  use KoalemosWeb, :live_view
  require Logger

  alias KoalemosWeb.ChatPanel
  alias Koalemos.{EngineManager, Engine}
  alias Koalemos.Routines.ThinkingTestRoutine

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Sequential Thinking Test",
        routine_id: nil,
        messages: [],
        current_step: nil,
        recent_events: [],
        # Only show debug in dev mode (Mix not available in releases)
        show_debug: Code.ensure_loaded?(Mix) and Mix.env() == :dev,
        status: :running,
        last_error: nil
      )
      |> then(fn socket ->
        if connected?(socket) do
          start_routine(socket)
        else
          socket
        end
      end)

    {:ok, socket}
  end

  @impl true
  def handle_info(:check_uploads, socket) do
    # Forward to nested UserInputComponent
    alias KoalemosWeb.UserInputComponent
    send_update(UserInputComponent, id: "chat-panel-input", check_uploads: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:clear_sent_feedback, component_id}, socket) do
    # Forward to nested UserInputComponent
    alias KoalemosWeb.UserInputComponent
    send_update(UserInputComponent, id: component_id, clear_sent_feedback: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_input_submitted, user_input_data}, socket) do
    text = Map.get(user_input_data, :text, "")
    Logger.info("[ThinkingTestLive] User input submitted: #{text}")

    # Send user input to routine
    Engine.send_external_event(socket.assigns.routine_id, :user_input, user_input_data)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_messages, new_messages}, socket) do
    Logger.debug("[ThinkingTestLive] Received #{length(new_messages)} new message(s)")

    updated_messages = socket.assigns.messages ++ new_messages
    {:noreply, assign(socket, messages: updated_messages)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "routine_completed"} = event}, socket) do
    Logger.info("[ThinkingTestLive] Routine completed")

    error = get_in(event, [:metadata, :final_context, :error])
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
    Logger.error("[ThinkingTestLive] Routine error: #{error_msg}")

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
    Logger.debug("[ThinkingTestLive] Step started: #{step} (#{inspect(step_module)})")

    socket =
      socket
      |> assign(current_step: step)
      |> add_event("step_started", %{step: step, module: step_module})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "step_completed"} = event}, socket) do
    step = event.step_id
    Logger.debug("[ThinkingTestLive] Step completed: #{step}")

    socket = add_event(socket, "step_completed", %{step: step})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:routine_event, event}, socket) do
    # Log all other routine events for debugging
    Logger.debug("[ThinkingTestLive] Routine event: #{inspect(event.event_type)}")
    {:noreply, socket}
  end

  defp add_event(socket, event_type, details) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    event = %{type: event_type, details: details, time: timestamp}

    recent = [event | socket.assigns.recent_events] |> Enum.take(20)
    assign(socket, recent_events: recent)
  end

  defp start_routine(socket) do
    routine_id = "thinking-test-#{:erlang.unique_integer([:positive])}"

    # Subscribe to routine events
    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

    initial_context = ThinkingTestRoutine.initial_context()

    case EngineManager.start_routine(routine_id, ThinkingTestRoutine, initial_context) do
      {:ok, _pid} ->
        Logger.info("[ThinkingTestLive] Started routine #{routine_id}")
        assign(socket, routine_id: routine_id)

      {:error, reason} ->
        Logger.error("[ThinkingTestLive] Failed to start routine: #{inspect(reason)}")

        socket
        |> put_flash(:error, "Failed to start routine: #{inspect(reason)}")
        |> assign(routine_id: nil)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-teal-50 via-white to-blue-50 flex flex-col">
      <!-- Header -->
      <div class="bg-white border-b border-slate-200 px-6 py-4">
        <div class="max-w-7xl mx-auto flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-slate-800">Sequential Thinking Test</h1>
            <p class="text-sm text-slate-600 mt-1">
              Test step-by-step reasoning with complex problems
            </p>
          </div>
          <div class="flex items-center gap-3">
            <!-- Current Step -->
            <%= if @current_step do %>
              <div class="text-xs text-slate-500 font-mono">
                step: {@current_step}
              </div>
            <% else %>
              <div class="text-xs text-slate-400 font-mono">
                step: waiting
              </div>
            <% end %>
            <!-- Routine ID -->
            <div class="text-xs text-slate-400 font-mono">
              {@routine_id}
            </div>
            <a
              href="/test"
              class="px-4 py-2 text-slate-600 hover:text-slate-800 transition-colors"
            >
              ← Back to Tests
            </a>
          </div>
        </div>
      </div>
      <!-- Instructions -->
      <div class="bg-teal-50 border-b border-teal-200 px-6 py-3">
        <div class="max-w-7xl mx-auto">
          <p class="text-sm text-teal-800">
            <strong>Try these examples:</strong>
            "How would you design a distributed caching system?" •
            "Break down the steps to migrate a monolith to microservices" •
            "Plan a refactoring strategy for a legacy codebase"
          </p>
        </div>
      </div>
      <!-- Debug Panel -->
      <%= if @show_debug do %>
        <div class="bg-slate-800 text-white border-b border-slate-700">
          <div class="max-w-7xl mx-auto px-6 py-2">
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
              <%= if length(@recent_events) > 0 do %>
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
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
      <!-- Main Content -->
      <div class="flex-1 overflow-hidden flex">
        <div class="flex-1 bg-white flex flex-col overflow-hidden max-w-7xl mx-auto w-full">
          <.live_component
            module={ChatPanel}
            id="chat-panel"
            routine_id={@routine_id}
            messages={@messages}
            mock_responses={false}
            current_step={nil}
            show_screenshot_checkbox={false}
          />
        </div>
      </div>
    </div>
    """
  end

  defp format_time(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%H:%M:%S")
      _ -> "??:??:??"
    end
  end
end
