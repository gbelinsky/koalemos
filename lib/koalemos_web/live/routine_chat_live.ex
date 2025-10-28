defmodule KoalemosWeb.RoutineChatLive do
  @moduledoc """
  Main chat interface for a routine session.

  Displays the ChatPanel component and manages the routine lifecycle.

  ## Sprint 5 (Current)
  - Displays routine_id from URL
  - Shows "ready" status
  - ChatPanel works with mock responses

  ## Sprint 6 (Future)
  - Start routine via EngineManager
  - Subscribe to routine events via PubSub
  - Handle real AI messages
  - Display routine status (running, completed, error)
  """
  use KoalemosWeb, :live_view

  alias KoalemosWeb.ChatPanel

  @impl true
  def mount(%{"routine_id" => routine_id}, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Chat",
       routine_id: routine_id,
       status: :ready
     )}
  end

  @impl true
  def handle_info(:check_uploads, socket) do
    # Forward to nested UserInputComponent (inside ChatPanel)
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
  def handle_info({:user_input_submitted, %{text: text, images: images}}, socket) do
    require Logger
    Logger.info("User input submitted in RoutineChatLive: text=#{text}, images=#{length(images)}")

    # In Sprint 5: just log it
    # In Sprint 6: will send to routine via EngineManager
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-100">
      <!-- Header -->
      <div class="bg-white border-b border-slate-200 shadow-sm">
        <div class="max-w-6xl mx-auto px-4 py-3 flex items-center justify-between">
          <div class="flex items-center gap-3">
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
          </div>
          <div class="flex items-center gap-3">
            <!-- Status Badge -->
            <div class="flex items-center gap-2 px-3 py-1 bg-green-50 border border-green-200 rounded-full">
              <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
              <span class="text-sm text-green-700"><%= status_text(@status) %></span>
            </div>
            <!-- Routine ID (small, subtle) -->
            <div class="text-xs text-slate-400 font-mono">
              <%= @routine_id %>
            </div>
          </div>
        </div>
      </div>
      <!-- Chat Panel (fills remaining space) -->
      <div class="flex-1 overflow-hidden">
        <div class="max-w-6xl mx-auto h-full">
          <.live_component
            module={ChatPanel}
            id="chat-panel"
            routine_id={@routine_id}
            mock_responses={true}
          />
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp status_text(:ready), do: "ready"
  defp status_text(:running), do: "running"
  defp status_text(:completed), do: "completed"
  defp status_text(:error), do: "error"
  defp status_text(_), do: "unknown"
end
