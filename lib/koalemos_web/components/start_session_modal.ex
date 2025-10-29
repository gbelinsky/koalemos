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
  def mount(socket) do
    {:ok, assign(socket, provider: "anthropic", model: "claude-haiku-4-5")}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Initialize provider/model if not already set
    socket =
      socket
      |> assign_new(:provider, fn -> "anthropic" end)
      |> assign_new(:model, fn -> "claude-haiku-4-5" end)

    {:ok, socket}
  end

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

            <form phx-change="update_config" phx-target={@myself}>
              <!-- Provider Selection -->
              <div class="mb-4">
                <label class="block text-sm font-medium text-slate-700 mb-2">
                  AI Provider
                </label>
                <select
                  name="provider"
                  class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="anthropic" selected={@provider == "anthropic"}>Anthropic</option>
                  <option value="openai" selected={@provider == "openai"}>OpenAI</option>
                  <option value="ollama" selected={@provider == "ollama"}>Ollama (Local)</option>
                </select>
              </div>

              <!-- Model Input -->
              <div class="mb-6">
                <label class="block text-sm font-medium text-slate-700 mb-2">
                  Model
                  <span class="text-slate-400 font-normal text-xs ml-1">
                    (<%= model_hint(@provider) %>)
                  </span>
                </label>
                <input
                  type="text"
                  name="model"
                  value={@model}
                  placeholder={model_placeholder(@provider)}
                  class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-sm"
                />
              </div>
            </form>
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
  def handle_event("update_config", %{"provider" => provider, "model" => model}, socket) do
    # If provider changed, update to default model for that provider
    socket = if provider != socket.assigns.provider do
      default_model = case provider do
        "anthropic" -> "claude-haiku-4-5"
        "openai" -> "gpt-4o"
        "ollama" -> "llama3.2"
        _ -> "claude-haiku-4-5"
      end
      assign(socket, provider: provider, model: default_model)
    else
      # Provider didn't change, just update model
      assign(socket, provider: provider, model: model)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_chat", _params, socket) do
    # Generate truly unique routine ID with timestamp and random component
    routine_id = "routine-#{System.system_time(:millisecond)}-#{:rand.uniform(999999)}"

    # Navigate with provider and model as query params
    url = "/chat/#{routine_id}?provider=#{socket.assigns.provider}&model=#{URI.encode_www_form(socket.assigns.model)}"

    send(self(), {:close_modal})
    {:noreply, push_navigate(socket, to: url)}
  end

  # Helper functions for model hints
  defp model_hint("anthropic"), do: "e.g. claude-haiku-4-5, claude-sonnet-4-5"
  defp model_hint("openai"), do: "e.g. gpt-4o, gpt-4o-mini"
  defp model_hint("ollama"), do: "e.g. llama3.2, mistral"
  defp model_hint(_), do: "enter model name"

  defp model_placeholder("anthropic"), do: "claude-haiku-4-5"
  defp model_placeholder("openai"), do: "gpt-4o"
  defp model_placeholder("ollama"), do: "llama3.2"
  defp model_placeholder(_), do: "model-name"
end
