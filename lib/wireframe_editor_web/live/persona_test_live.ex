defmodule WireframeEditorWeb.PersonaTestLive do
  @moduledoc """
  Interactive persona testing page.

  Provides a complete testing environment for PersonaLens:
  - Full chat interface with AI
  - Controls to select tone, expertise, and style
  - Real-time persona switching
  - See how AI behavior changes with different configs

  Route: /test/persona
  """
  use WireframeEditorWeb, :live_view
  require Logger

  alias WireframeEditorWeb.ChatPanel
  alias Koalemos.{EngineManager, Engine}
  alias Koalemos.Routines.PersonaTestRoutine

  @impl true
  def mount(_params, _session, socket) do
    # Default persona config
    initial_persona = %{
      tone: :professional,
      expertise: [:technical],
      style: :balanced
    }

    socket =
      socket
      |> assign(
        page_title: "Persona Test",
        # Current persona config
        current_persona: initial_persona,
        # Pending persona (being configured but not applied yet)
        pending_persona: initial_persona,
        # UI state
        config_panel_open: true,
        routine_id: nil,
        messages: []
      )
      |> then(fn socket ->
        if connected?(socket) do
          # Start routine with default persona
          start_routine_with_persona(socket, initial_persona)
        else
          socket
        end
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event("update_tone", %{"tone" => tone}, socket) do
    tone_atom = String.to_existing_atom(tone)
    pending = Map.put(socket.assigns.pending_persona, :tone, tone_atom)
    {:noreply, assign(socket, pending_persona: pending)}
  end

  @impl true
  def handle_event("toggle_expertise", %{"expertise" => expertise}, socket) do
    expertise_atom = String.to_existing_atom(expertise)
    current_expertise = socket.assigns.pending_persona.expertise

    new_expertise =
      if expertise_atom in current_expertise do
        List.delete(current_expertise, expertise_atom)
      else
        [expertise_atom | current_expertise]
      end

    pending = Map.put(socket.assigns.pending_persona, :expertise, new_expertise)
    {:noreply, assign(socket, pending_persona: pending)}
  end

  @impl true
  def handle_event("update_style", %{"style" => style}, socket) do
    style_atom = String.to_existing_atom(style)
    pending = Map.put(socket.assigns.pending_persona, :style, style_atom)
    {:noreply, assign(socket, pending_persona: pending)}
  end

  @impl true
  def handle_event("apply_persona", _params, socket) do
    Logger.info(
      "[PersonaTestLive] Applying new persona config: #{inspect(socket.assigns.pending_persona)}"
    )

    # Stop old routine if exists
    if socket.assigns.routine_id do
      EngineManager.stop_routine(socket.assigns.routine_id)
    end

    # Start new routine with new persona
    socket = start_routine_with_persona(socket, socket.assigns.pending_persona)

    {:noreply, assign(socket, current_persona: socket.assigns.pending_persona, messages: [])}
  end

  @impl true
  def handle_event("toggle_config_panel", _params, socket) do
    {:noreply, assign(socket, config_panel_open: !socket.assigns.config_panel_open)}
  end

  @impl true
  def handle_info(:check_uploads, socket) do
    # Forward to nested UserInputComponent
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
  def handle_info({:user_input_submitted, user_input_data}, socket) do
    text = Map.get(user_input_data, :text, "")
    Logger.info("[PersonaTestLive] User input submitted: #{text}")

    # Send user input to routine (pass through all data from UserInputComponent)
    Engine.send_external_event(socket.assigns.routine_id, :user_input, user_input_data)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_messages, new_messages}, socket) do
    Logger.debug("[PersonaTestLive] Received #{length(new_messages)} new message(s)")

    updated_messages = socket.assigns.messages ++ new_messages
    {:noreply, assign(socket, messages: updated_messages)}
  end

  @impl true
  def handle_info({:routine_event, _event}, socket) do
    # Ignore other routine events
    {:noreply, socket}
  end

  # Helper to start a new routine with given persona config
  defp start_routine_with_persona(socket, persona_config) do
    routine_id = "persona-test-#{:erlang.unique_integer([:positive])}"

    # Subscribe to routine events
    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

    # Build user context with PersonaLens config
    user_context = %{
      lenses: [
        ["Koalemos.Lenses.PersonaLens", persona_config]
      ],
      llm_provider: "anthropic",
      llm_model: "claude-haiku-4-5"
    }

    case EngineManager.start_routine(routine_id, PersonaTestRoutine, user_context) do
      {:ok, _pid} ->
        Logger.info(
          "[PersonaTestLive] Started routine #{routine_id} with persona: #{inspect(persona_config)}"
        )

      {:error, reason} ->
        Logger.error("[PersonaTestLive] Failed to start routine: #{inspect(reason)}")
    end

    assign(socket, routine_id: routine_id)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-100">
      <!-- Header -->
      <div class="bg-white border-b border-slate-200 shadow-sm">
        <div class="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
          <div>
            <h1 class="text-xl font-semibold text-slate-800">Persona Lens Test</h1>
            <p class="text-sm text-slate-600 mt-1">
              Experiment with dimensional persona configurations
            </p>
          </div>
          <div class="flex items-center gap-4">
            <a
              href="/test"
              class="text-sm text-blue-600 hover:text-blue-800 font-medium transition-colors"
            >
              ← Test Pages
            </a>
          </div>
        </div>
      </div>
      <!-- Instructions -->
      <div class="bg-blue-50 border-b border-blue-200">
        <div class="max-w-7xl mx-auto px-4 py-2">
          <p class="text-sm text-blue-800">
            <strong>How to test:</strong>
            Select tone, expertise areas, and style from the controls below, then click "Apply Persona" to restart the chat with the new configuration. Try asking the same question with different personas to see how responses change!
          </p>
        </div>
      </div>
      <!-- Main Content -->
      <div class="flex-1 overflow-hidden flex">
        <!-- Config Panel (left side) -->
        <div class="w-80 border-r border-slate-300 bg-white flex flex-col overflow-y-auto">
          <div class="p-4 space-y-6">
            <!-- Current Persona Display -->
            <div class="bg-slate-50 rounded-lg p-4 border border-slate-200">
              <h3 class="text-sm font-semibold text-slate-700 mb-2">Active Persona</h3>
              <div class="space-y-2 text-sm">
                <div>
                  <span class="text-slate-600">Tone:</span>
                  <span class="ml-2 font-medium text-slate-900">
                    {format_atom(@current_persona.tone)}
                  </span>
                </div>
                <div>
                  <span class="text-slate-600">Expertise:</span>
                  <div class="mt-1 flex flex-wrap gap-1">
                    <%= for exp <- @current_persona.expertise do %>
                      <span class="px-2 py-0.5 bg-blue-100 text-blue-800 rounded text-xs font-medium">
                        {format_atom(exp)}
                      </span>
                    <% end %>
                  </div>
                </div>
                <div>
                  <span class="text-slate-600">Style:</span>
                  <span class="ml-2 font-medium text-slate-900">
                    {format_atom(@current_persona.style)}
                  </span>
                </div>
              </div>
            </div>
            <!-- Tone Selection -->
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-2">
                Tone (select one)
              </label>
              <div class="space-y-2">
                <%= for tone <- [:professional, :casual, :friendly, :empathetic] do %>
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      type="radio"
                      name="tone"
                      value={tone}
                      checked={@pending_persona.tone == tone}
                      phx-click="update_tone"
                      phx-value-tone={tone}
                      class="w-4 h-4 text-blue-600 focus:ring-blue-500"
                    />
                    <span class="text-sm text-slate-700">{format_atom(tone)}</span>
                  </label>
                <% end %>
              </div>
            </div>
            <!-- Expertise Selection -->
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-2">
                Expertise (select multiple)
              </label>
              <div class="space-y-2">
                <%= for expertise <- [:technical, :creative, :business, :analytical, :ux] do %>
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      type="checkbox"
                      value={expertise}
                      checked={expertise in @pending_persona.expertise}
                      phx-click="toggle_expertise"
                      phx-value-expertise={expertise}
                      class="w-4 h-4 text-blue-600 rounded focus:ring-blue-500"
                    />
                    <span class="text-sm text-slate-700">{format_atom(expertise)}</span>
                  </label>
                <% end %>
              </div>
            </div>
            <!-- Style Selection -->
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-2">
                Style (select one)
              </label>
              <div class="space-y-2">
                <%= for style <- [:concise, :detailed, :balanced, :storytelling] do %>
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      type="radio"
                      name="style"
                      value={style}
                      checked={@pending_persona.style == style}
                      phx-click="update_style"
                      phx-value-style={style}
                      class="w-4 h-4 text-blue-600 focus:ring-blue-500"
                    />
                    <span class="text-sm text-slate-700">{format_atom(style)}</span>
                  </label>
                <% end %>
              </div>
            </div>
            <!-- Apply Button -->
            <button
              phx-click="apply_persona"
              class={"w-full px-4 py-3 rounded-lg font-medium transition-colors " <>
                if(@pending_persona == @current_persona,
                  do: "bg-slate-300 text-slate-500 cursor-not-allowed",
                  else: "bg-blue-600 text-white hover:bg-blue-700"
                )}
              disabled={@pending_persona == @current_persona}
            >
              <%= if @pending_persona == @current_persona do %>
                No Changes
              <% else %>
                Apply Persona & Restart Chat
              <% end %>
            </button>
            <!-- Preset Examples -->
            <div class="pt-4 border-t border-slate-200">
              <h3 class="text-sm font-semibold text-slate-700 mb-3">Quick Presets</h3>
              <div class="space-y-2 text-xs">
                <div class="p-2 bg-green-50 border border-green-200 rounded">
                  <div class="font-medium text-green-900">Tech Lead</div>
                  <div class="text-green-700">Professional + Technical + Balanced</div>
                </div>
                <div class="p-2 bg-purple-50 border border-purple-200 rounded">
                  <div class="font-medium text-purple-900">UX Designer</div>
                  <div class="text-purple-700">Friendly + Creative/UX + Storytelling</div>
                </div>
                <div class="p-2 bg-orange-50 border border-orange-200 rounded">
                  <div class="font-medium text-orange-900">Product Manager</div>
                  <div class="text-orange-700">Empathetic + Business/UX + Detailed</div>
                </div>
                <div class="p-2 bg-blue-50 border border-blue-200 rounded">
                  <div class="font-medium text-blue-900">Data Analyst</div>
                  <div class="text-blue-700">Professional + Analytical + Concise</div>
                </div>
              </div>
            </div>
          </div>
        </div>
        <!-- Chat Panel (right side) -->
        <div class="flex-1 bg-white flex flex-col overflow-hidden">
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

  # Helper to format atom for display
  defp format_atom(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
