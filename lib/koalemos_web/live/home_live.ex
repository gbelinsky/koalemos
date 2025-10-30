defmodule KoalemosWeb.HomeLive do
  @moduledoc """
  Landing page for Koalemos.

  Simple home page with a "Start Chat Session" button that opens a modal
  to begin a new chat routine.
  """
  use KoalemosWeb, :live_view

  alias KoalemosWeb.StartSessionModal

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Koalemos",
       show_modal: false
     )}
  end

  @impl true
  def handle_event("open_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_info({:close_modal}, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def handle_info({:start_chat, _routine_id}, socket) do
    # Modal handles navigation, just close modal state
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-50 to-gray-100 flex items-center justify-center p-8">
      <div class="max-w-2xl w-full text-center">
        <!-- Logo/Title -->
        <div class="mb-8">
          <h1 class="text-6xl font-bold text-slate-800 mb-4">koalemos</h1>
          <p class="text-xl text-slate-600">
            your ai conversation companion
          </p>
        </div>
        <!-- Description -->
        <p class="text-lg text-slate-500 mb-12 max-w-xl mx-auto">
          start a conversation with an ai assistant. chat naturally with text and images.
        </p>
        <!-- Start Button -->
        <button
          phx-click="open_modal"
          class="px-8 py-4 bg-gradient-to-br from-blue-500 to-indigo-600 text-white text-lg rounded-2xl hover:from-blue-600 hover:to-indigo-700 hover:scale-105 transition-all duration-200 shadow-[2px_2px_12px_-2px_rgba(59,130,246,0.4)] hover:shadow-[3px_3px_16px_-2px_rgba(59,130,246,0.5)] border-r-[3px] border-b-[2px] border-t border-blue-400/30"
        >
          start chat session
        </button>
        <!-- Footer -->
        <div class="mt-16 text-sm text-slate-400">
          <a href="/test" class="hover:text-slate-600 transition-colors">
            view test pages
          </a>
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
end
