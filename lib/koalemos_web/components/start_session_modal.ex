defmodule KoalemosWeb.StartSessionModal do
  @moduledoc """
  Modal for starting a new chat routine.

  Features:
  - Displays routine selection (hardcoded "Test Chat" for M2)
  - Generates unique routine_id
  - Navigates to chat page on start
  - Reusable across pages

  ## Usage

  ```heex
  <.live_component
    module={KoalemosWeb.StartSessionModal}
    id="start-session-modal"
    show={@show_modal}
  />
  ```

  ## Events

  The parent must handle:
  - `close_modal` - User clicked cancel or clicked away
  """
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @show do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <div
            class="bg-white rounded-2xl shadow-2xl max-w-md w-full p-8"
            phx-click-away="close_modal"
            phx-target={@myself}
          >
            <h2 class="text-2xl font-bold text-slate-800 mb-4">start new chat</h2>
            <p class="text-slate-600 mb-6">
              ready to begin a new conversation?
            </p>
            <!-- Hardcoded routine selection (for M2) -->
            <div class="mb-6 p-4 bg-slate-50 rounded-xl border-2 border-slate-200">
              <div class="flex items-center gap-3">
                <svg class="w-6 h-6 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"
                  />
                </svg>
                <div class="text-left">
                  <div class="font-semibold text-slate-800">test chat</div>
                  <div class="text-sm text-slate-500">basic conversation assistant</div>
                </div>
              </div>
            </div>
            <!-- Action Buttons -->
            <div class="flex gap-3">
              <button
                phx-click="close_modal"
                phx-target={@myself}
                class="flex-1 px-4 py-3 bg-slate-100 text-slate-700 rounded-xl hover:bg-slate-200 transition-colors"
              >
                cancel
              </button>
              <button
                phx-click="start_chat"
                phx-target={@myself}
                class="flex-1 px-4 py-3 bg-gradient-to-br from-blue-500 to-indigo-600 text-white rounded-xl hover:from-blue-600 hover:to-indigo-700 transition-all duration-200 shadow-md"
              >
                start
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    send(self(), {:close_modal})
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_chat", _params, socket) do
    # Generate truly unique routine ID with timestamp and random component
    routine_id = "routine-#{System.system_time(:millisecond)}-#{:rand.uniform(999999)}"

    # Send to parent and navigate
    send(self(), {:start_chat, routine_id})
    {:noreply, push_navigate(socket, to: "/chat/#{routine_id}")}
  end
end
