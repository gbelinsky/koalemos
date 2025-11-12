defmodule KoalemosWeb.LensCombinatorLive do
  @moduledoc """
  Multi-Lens Testing Interface for Sprint 8.

  Allows developers to:
  - Select multiple lenses (PersonaLens, SequentialThinking, WireframeEditor)
  - Configure options for each selected lens
  - Start routine with chosen lens combination
  - Validate that lenses work together without conflicts

  Uses WireframeTestRoutine (full tool execution support) to ensure all lenses
  can use their tools if they provide any.

  Route: /test/lens-combinator
  """
  use KoalemosWeb, :live_view
  require Logger

  alias KoalemosWeb.ChatPanel
  alias Koalemos.{EngineManager, Engine}
  alias Koalemos.Lenses.{PersonaLens, SequentialThinking, WireframeEditor}

  @available_lenses [
    %{
      id: :persona,
      name: "PersonaLens",
      module: PersonaLens,
      description: "Adds personality, tone, and communication style to AI responses",
      config_options: [:tone, :expertise, :style]
    },
    %{
      id: :thinking,
      name: "SequentialThinking",
      module: SequentialThinking,
      description: "Step-by-step reasoning visible to user",
      config_options: []
    },
    %{
      id: :wireframe,
      name: "WireframeEditor",
      module: WireframeEditor,
      description: "Interactive wireframe editing with 9 tools",
      config_options: [:wireframe_sample]
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Lens Combinator",
        # Available lenses
        available_lenses: @available_lenses,
        # Selected lenses (list of lens IDs)
        selected_lenses: [],
        # Configuration for each lens
        lens_configs: %{
          persona: %{
            tone: :professional,
            expertise: [:technical],
            style: :balanced
          },
          thinking: %{},
          wireframe: %{
            wireframe_sample: :simple
          }
        },
        # Routine state
        routine_id: nil,
        routine_running: false,
        messages: [],
        # UI state
        config_panel_open: true,
        error_message: nil
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_lens", %{"lens_id" => lens_id}, socket) do
    lens_atom = String.to_existing_atom(lens_id)
    selected = socket.assigns.selected_lenses

    new_selected =
      if lens_atom in selected do
        List.delete(selected, lens_atom)
      else
        [lens_atom | selected]
      end

    {:noreply, assign(socket, selected_lenses: new_selected)}
  end

  @impl true
  def handle_event("update_persona_tone", %{"tone" => tone}, socket) do
    tone_atom = String.to_existing_atom(tone)
    lens_configs = put_in(socket.assigns.lens_configs, [:persona, :tone], tone_atom)
    {:noreply, assign(socket, lens_configs: lens_configs)}
  end

  @impl true
  def handle_event("toggle_persona_expertise", %{"expertise" => expertise}, socket) do
    expertise_atom = String.to_existing_atom(expertise)
    current_expertise = socket.assigns.lens_configs.persona.expertise

    new_expertise =
      if expertise_atom in current_expertise do
        List.delete(current_expertise, expertise_atom)
      else
        [expertise_atom | current_expertise]
      end

    lens_configs = put_in(socket.assigns.lens_configs, [:persona, :expertise], new_expertise)
    {:noreply, assign(socket, lens_configs: lens_configs)}
  end

  @impl true
  def handle_event("update_persona_style", %{"style" => style}, socket) do
    style_atom = String.to_existing_atom(style)
    lens_configs = put_in(socket.assigns.lens_configs, [:persona, :style], style_atom)
    {:noreply, assign(socket, lens_configs: lens_configs)}
  end

  @impl true
  def handle_event("update_wireframe_sample", %{"sample" => sample}, socket) do
    sample_atom = String.to_existing_atom(sample)

    lens_configs =
      put_in(socket.assigns.lens_configs, [:wireframe, :wireframe_sample], sample_atom)

    {:noreply, assign(socket, lens_configs: lens_configs)}
  end

  @impl true
  def handle_event("start_routine", _params, socket) do
    if socket.assigns.selected_lenses == [] do
      {:noreply, assign(socket, error_message: "Please select at least one lens")}
    else
      socket = start_multi_lens_routine(socket)
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stop_routine", _params, socket) do
    if socket.assigns.routine_id do
      EngineManager.stop_routine(socket.assigns.routine_id)
    end

    {:noreply, assign(socket, routine_id: nil, routine_running: false)}
  end

  @impl true
  def handle_event("toggle_config_panel", _params, socket) do
    {:noreply, assign(socket, config_panel_open: not socket.assigns.config_panel_open)}
  end

  @impl true
  def handle_event("dismiss_error", _params, socket) do
    {:noreply, assign(socket, error_message: nil)}
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
    Logger.info("[LensCombinator] User input submitted: #{text}")

    # Send user input to routine (pass through all data from UserInputComponent)
    Engine.send_external_event(socket.assigns.routine_id, :user_input, user_input_data)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_messages, new_messages}, socket) do
    Logger.debug("[LensCombinator] Received #{length(new_messages)} new message(s)")

    updated_messages = socket.assigns.messages ++ new_messages
    {:noreply, assign(socket, messages: updated_messages)}
  end

  @impl true
  def handle_info({:routine_event, _event}, socket) do
    # Ignore other routine events
    {:noreply, socket}
  end

  # Private helpers

  defp start_multi_lens_routine(socket) do
    selected_lenses = socket.assigns.selected_lenses
    lens_configs = socket.assigns.lens_configs

    # Build lens list with configurations
    # Format: list of [module_string, config] or just module_string
    lenses =
      Enum.map(selected_lenses, fn lens_id ->
        case lens_id do
          :persona ->
            config = lens_configs.persona
            ["Koalemos.Lenses.PersonaLens", config]

          :thinking ->
            "Koalemos.Lenses.SequentialThinking"

          :wireframe ->
            config = lens_configs.wireframe
            ["Koalemos.Lenses.WireframeEditor", config]
        end
      end)

    # Create routine configuration
    routine_config = %{
      lenses: lenses,
      llm_provider: "anthropic",
      llm_model: "claude-sonnet-4-5",
      # Higher limit for tool execution and wireframe context
      max_tokens: 64000,
      temperature: 0.7
    }

    # Generate unique routine ID
    routine_id = "lens-combo-#{:erlang.unique_integer([:positive])}"

    Logger.info(
      "[LensCombinator] Starting routine #{routine_id} with lenses: #{inspect(selected_lenses)}"
    )

    Logger.info("[LensCombinator] Lens configs: #{inspect(lens_configs)}")

    case EngineManager.start_routine(
           routine_id,
           Koalemos.Routines.WireframeTestRoutine,
           routine_config
         ) do
      {:ok, _pid} ->
        # Subscribe to routine events and messages (both topics)
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

        assign(socket,
          routine_id: routine_id,
          routine_running: true,
          messages: [],
          error_message: nil
        )

      {:error, reason} ->
        error_text =
          case reason do
            msg when is_binary(msg) -> msg
            other -> inspect(other)
          end

        Logger.error("[LensCombinator] Failed to start routine: #{inspect(reason)}")
        assign(socket, error_message: error_text)
    end
  end

  # Render helpers

  defp lens_selected?(selected_lenses, lens_id) do
    lens_id in selected_lenses
  end

  defp lens_info(lens_id) do
    Enum.find(@available_lenses, fn lens -> lens.id == lens_id end)
  end

  defp render_lens_config(assigns, :persona, config) do
    assigns = assign(assigns, :config, config)

    ~H"""
    <div class="space-y-4 bg-gray-50 dark:bg-gray-800 p-4 rounded-lg">
      <h4 class="font-medium text-gray-900 dark:text-gray-100">Persona Configuration</h4>

      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Tone
        </label>
        <select
          phx-change="update_persona_tone"
          name="tone"
          class="block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
        >
          <option value="professional" selected={@config.tone == :professional}>Professional</option>
          <option value="casual" selected={@config.tone == :casual}>Casual</option>
          <option value="enthusiastic" selected={@config.tone == :enthusiastic}>Enthusiastic</option>
          <option value="empathetic" selected={@config.tone == :empathetic}>Empathetic</option>
          <option value="concise" selected={@config.tone == :concise}>Concise</option>
        </select>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Expertise (select multiple)
        </label>
        <div class="space-y-2">
          <%= for expertise <- [:technical, :creative, :analytical, :social] do %>
            <label class="flex items-center">
              <input
                type="checkbox"
                phx-click="toggle_persona_expertise"
                phx-value-expertise={expertise}
                checked={expertise in @config.expertise}
                class="rounded border-gray-300 dark:border-gray-600 text-indigo-600 focus:ring-indigo-500"
              />
              <span class="ml-2 text-sm text-gray-700 dark:text-gray-300">
                {expertise |> Atom.to_string() |> String.capitalize()}
              </span>
            </label>
          <% end %>
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Style
        </label>
        <select
          phx-change="update_persona_style"
          name="style"
          class="block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
        >
          <option value="detailed" selected={@config.style == :detailed}>Detailed</option>
          <option value="balanced" selected={@config.style == :balanced}>Balanced</option>
          <option value="brief" selected={@config.style == :brief}>Brief</option>
        </select>
      </div>
    </div>
    """
  end

  defp render_lens_config(assigns, :thinking, _config) do
    ~H"""
    <div class="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg">
      <p class="text-sm text-gray-600 dark:text-gray-400">
        SequentialThinking has no configuration options.
        It will automatically show step-by-step reasoning.
      </p>
    </div>
    """
  end

  defp render_lens_config(assigns, :wireframe, config) do
    assigns = assign(assigns, :config, config)

    ~H"""
    <div class="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg">
      <h4 class="font-medium text-gray-900 dark:text-gray-100 mb-4">Wireframe Configuration</h4>

      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Initial Sample
        </label>
        <select
          phx-change="update_wireframe_sample"
          name="sample"
          class="block w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
        >
          <option value="simple" selected={@config.wireframe_sample == :simple}>Simple</option>
          <option value="medium" selected={@config.wireframe_sample == :medium}>Medium</option>
          <option value="complex" selected={@config.wireframe_sample == :complex}>Complex</option>
        </select>
        <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">
          Note: WireframeEditor requires WireframePreview infrastructure.
          For multi-lens testing, focus on context/tool integration.
        </p>
      </div>
    </div>
    """
  end

  # Template

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white dark:bg-gray-900">
      <header class="bg-indigo-600 dark:bg-indigo-800 shadow">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div class="flex justify-between items-center">
            <div>
              <h1 class="text-2xl font-bold text-white">Multi-Lens Testing Interface</h1>
              <p class="text-sm text-indigo-200 dark:text-indigo-300 mt-1">
                Sprint 8 - Test lens combinations and configurations
              </p>
            </div>
            <a
              href="/test"
              class="px-4 py-2 bg-white dark:bg-gray-700 text-indigo-600 dark:text-indigo-400 rounded-md hover:bg-gray-50 dark:hover:bg-gray-600 font-medium transition-colors"
            >
              ← Back to Test Index
            </a>
          </div>
        </div>
      </header>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Error Display -->
        <%= if @error_message do %>
          <div class="mb-6 bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-700 rounded-lg p-4">
            <div class="flex items-start">
              <div class="flex-shrink-0">
                <svg
                  class="h-5 w-5 text-red-400 dark:text-red-500"
                  fill="currentColor"
                  viewBox="0 0 20 20"
                >
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                    clip-rule="evenodd"
                  />
                </svg>
              </div>
              <div class="ml-3 flex-1">
                <h3 class="text-sm font-medium text-red-800 dark:text-red-300 mb-2">
                  Error Starting Routine
                </h3>
                <div class="text-sm text-red-700 dark:text-red-400 bg-red-100 dark:bg-red-900/50 p-3 rounded font-mono text-xs overflow-x-auto">
                  {@error_message}
                </div>
                <p class="text-xs text-red-600 dark:text-red-400 mt-2">
                  Tip: You can select and copy the error text above
                </p>
              </div>
              <div class="ml-auto pl-3">
                <button
                  phx-click="dismiss_error"
                  class="inline-flex text-red-400 hover:text-red-500 dark:text-red-500 dark:hover:text-red-400 focus:outline-none"
                >
                  <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                    <path
                      fill-rule="evenodd"
                      d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Configuration Panel -->
          <div class="lg:col-span-1">
            <div class="bg-white dark:bg-gray-800 shadow rounded-lg overflow-hidden">
              <div class="px-4 py-5 border-b border-gray-200 dark:border-gray-700">
                <div class="flex justify-between items-center">
                  <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100">
                    Lens Selection
                  </h2>
                  <button
                    phx-click="toggle_config_panel"
                    class="text-gray-400 hover:text-gray-500 dark:hover:text-gray-300"
                  >
                    <%= if @config_panel_open do %>
                      <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                        <path
                          fill-rule="evenodd"
                          d="M5 10a1 1 0 011-1h8a1 1 0 110 2H6a1 1 0 01-1-1z"
                          clip-rule="evenodd"
                        />
                      </svg>
                    <% else %>
                      <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                        <path
                          fill-rule="evenodd"
                          d="M10 5a1 1 0 011 1v3h3a1 1 0 110 2h-3v3a1 1 0 11-2 0v-3H6a1 1 0 110-2h3V6a1 1 0 011-1z"
                          clip-rule="evenodd"
                        />
                      </svg>
                    <% end %>
                  </button>
                </div>
              </div>

              <%= if @config_panel_open do %>
                <div class="px-4 py-5 space-y-6">
                  <!-- Lens Selection Checkboxes -->
                  <div class="space-y-3">
                    <%= for lens <- @available_lenses do %>
                      <div class="relative flex items-start">
                        <div class="flex items-center h-5">
                          <input
                            id={"lens-#{lens.id}"}
                            type="checkbox"
                            phx-click="toggle_lens"
                            phx-value-lens_id={lens.id}
                            checked={lens_selected?(@selected_lenses, lens.id)}
                            class="focus:ring-indigo-500 h-4 w-4 text-indigo-600 border-gray-300 dark:border-gray-600 rounded"
                          />
                        </div>
                        <div class="ml-3 text-sm">
                          <label
                            for={"lens-#{lens.id}"}
                            class="font-medium text-gray-700 dark:text-gray-300 cursor-pointer"
                          >
                            {lens.name}
                          </label>
                          <p class="text-gray-500 dark:text-gray-400">
                            {lens.description}
                          </p>
                        </div>
                      </div>
                    <% end %>
                  </div>
                  
    <!-- Selected Lenses Count -->
                  <div class="bg-indigo-50 dark:bg-indigo-900/30 px-4 py-3 rounded-md">
                    <p class="text-sm text-indigo-800 dark:text-indigo-300">
                      <span class="font-medium">{length(@selected_lenses)}</span>
                      lens{if length(@selected_lenses) != 1, do: "es"} selected
                    </p>
                  </div>
                  
    <!-- Lens Configurations -->
                  <%= if @selected_lenses != [] do %>
                    <div class="space-y-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                      <h3 class="text-sm font-medium text-gray-900 dark:text-gray-100">
                        Lens Configurations
                      </h3>

                      <%= for lens_id <- @selected_lenses do %>
                        <div>
                          <h4 class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                            {lens_info(lens_id).name}
                          </h4>
                          {render_lens_config(
                            assigns,
                            lens_id,
                            Map.get(@lens_configs, lens_id)
                          )}
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                  
    <!-- Start/Stop Button -->
                  <div class="pt-4">
                    <%= if @routine_running do %>
                      <button
                        phx-click="stop_routine"
                        class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                      >
                        Stop Routine
                      </button>
                    <% else %>
                      <button
                        phx-click="start_routine"
                        class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                      >
                        Start Routine
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
            
    <!-- Info Box -->
            <div class="mt-6 bg-blue-50 dark:bg-blue-900/30 border border-blue-200 dark:border-blue-700 rounded-lg p-4">
              <h3 class="text-sm font-medium text-blue-900 dark:text-blue-300 mb-2">
                Testing Guide
              </h3>
              <ul class="text-sm text-blue-800 dark:text-blue-400 space-y-1 list-disc list-inside">
                <li>Select lens combinations to test</li>
                <li>Configure each selected lens</li>
                <li>Start routine and interact via chat</li>
                <li>Verify lenses work together</li>
                <li>Check for tool conflicts or errors</li>
              </ul>
            </div>
          </div>
          
    <!-- Chat Panel -->
          <div class="lg:col-span-2">
            <%= if @routine_running do %>
              <.live_component
                module={ChatPanel}
                id="chat-panel"
                routine_id={@routine_id}
                messages={@messages}
                title="Multi-Lens Chat"
              />
            <% else %>
              <div class="bg-white dark:bg-gray-800 shadow rounded-lg p-8 text-center">
                <svg
                  class="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"
                  />
                </svg>
                <h3 class="mt-2 text-sm font-medium text-gray-900 dark:text-gray-100">
                  No routine running
                </h3>
                <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">
                  Select lenses and click "Start Routine" to begin testing.
                </p>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
