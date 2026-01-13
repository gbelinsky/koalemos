defmodule KoalemosInspectorWeb.InspectorLive do
  @moduledoc """
  Main inspector interface with chat panel and inspector sidebar.

  Provides real-time visibility into:
  - Active lenses with toggle capability
  - Live lens_state updates
  - Rendered context (what agent sees)
  - Token count estimation
  """
  use KoalemosInspectorWeb, :live_view

  require Logger

  alias Koalemos.{EngineManager, Engine}
  alias WireframeEditorWeb.ChatPanel

  # Available providers and their preset models
  @provider_presets %{
    "anthropic" => [
      "claude-haiku-4-5",
      "claude-sonnet-4-5",
      "claude-opus-4-5"
    ],
    "ollama" => [
      "llama3.2",
      "qwen2.5-coder",
      "mistral"
    ],
    "openai" => [
      "gpt-4o-mini",
      "gpt-4o"
    ]
  }

  # Default routine suggestions (module name => display name)
  @routine_suggestions %{
    "Koalemos.Routines.TestChatRoutine" => "Test Chat",
    "Koalemos.Routines.PersonaTestRoutine" => "Persona Test",
    "Koalemos.Routines.ThinkingTestRoutine" => "Thinking Test",
    "Koalemos.Routines.CodeExplorerRoutine" => "Code Explorer",
    "Koalemos.Routines.TraditionalAgentRoutine" => "Traditional Agent"
  }

  @default_system_prompt "You are a software engineer. Help with coding tasks using the available tools."

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        page_title: "Inspector",
        # Setup state
        status: :setup,
        routine_input: "Koalemos.Routines.TestChatRoutine",
        routine_suggestions: @routine_suggestions,
        selected_provider: "anthropic",
        model_input: "claude-sonnet-4-5",
        provider_presets: @provider_presets,
        working_directory: File.cwd!(),
        system_prompt: @default_system_prompt,
        # Runtime state
        routine_id: nil,
        routine_module: nil,
        messages: [],
        current_step: nil,
        last_error: nil,
        # Inspector state
        inspector_tab: :lenses,
        inspector_open: true,
        inspector_width: "w-96",  # w-80 (320px), w-96 (384px), w-[500px]
        lens_state: %{},
        rendered_context: [],
        active_lenses: [],
        disabled_lenses: [],
        token_estimate: 0,
        llm_log: []
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("set_routine", %{"routine" => routine}, socket) do
    Logger.debug("set_routine: #{routine}")
    {:noreply, assign(socket, routine_input: routine)}
  end

  def handle_event("routine_form_change", %{"routine_input" => value}, socket) do
    Logger.debug("routine_form_change: #{value}")
    {:noreply, assign(socket, routine_input: value)}
  end

  def handle_event("set_provider", %{"provider" => provider}, socket) do
    Logger.debug("set_provider: #{provider}")
    # Reset model to first available for this provider
    models = Map.get(@provider_presets, provider, [])
    default_model = if models != [], do: hd(models), else: ""

    socket =
      socket
      |> assign(selected_provider: provider)
      |> assign(model_input: default_model)

    {:noreply, socket}
  end

  def handle_event("set_model", %{"model" => model}, socket) do
    Logger.debug("set_model: #{model}")
    {:noreply, assign(socket, model_input: model)}
  end

  def handle_event("model_form_change", %{"model_input" => model}, socket) do
    Logger.debug("model_form_change: #{model}")
    {:noreply, assign(socket, model_input: model)}
  end

  def handle_event("working_directory_form_change", %{"working_directory" => path}, socket) do
    Logger.debug("working_directory_form_change: #{path}")
    {:noreply, assign(socket, working_directory: path)}
  end

  def handle_event("system_prompt_form_change", %{"system_prompt" => prompt}, socket) do
    Logger.debug("system_prompt_form_change")
    {:noreply, assign(socket, system_prompt: prompt)}
  end

  def handle_event("start_session", _params, socket) do
    # Parse the routine module from the input string
    routine_input = String.trim(socket.assigns.routine_input)

    case parse_routine_module(routine_input) do
      {:ok, routine_module} ->
        start_routine_session(socket, routine_module)

      {:error, reason} ->
        {:noreply, assign(socket, last_error: reason)}
    end
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, inspector_tab: String.to_existing_atom(tab))}
  end

  def handle_event("toggle_inspector", _params, socket) do
    {:noreply, assign(socket, inspector_open: !socket.assigns.inspector_open)}
  end

  def handle_event("set_inspector_width", %{"width" => width}, socket) do
    {:noreply, assign(socket, inspector_width: width)}
  end

  def handle_event("toggle_lens", %{"lens" => lens_name}, socket) do
    disabled = socket.assigns.disabled_lenses

    new_disabled =
      if lens_name in disabled do
        List.delete(disabled, lens_name)
      else
        [lens_name | disabled]
      end

    {:noreply, assign(socket, disabled_lenses: new_disabled)}
  end

  def handle_event("reset_session", _params, socket) do
    # Reset to setup state
    socket =
      socket
      |> assign(
        status: :setup,
        routine_id: nil,
        routine_module: nil,
        messages: [],
        current_step: nil,
        last_error: nil,
        lens_state: %{},
        rendered_context: [],
        active_lenses: [],
        disabled_lenses: [],
        token_estimate: 0,
        llm_log: []
      )

    {:noreply, socket}
  end

  # Private helpers for session management

  defp parse_routine_module(input) when is_binary(input) do
    # Try to convert the string to an existing atom (module)
    # Prepend "Elixir." if not present for module lookup
    module_string =
      if String.starts_with?(input, "Elixir.") do
        input
      else
        "Elixir." <> input
      end

    try do
      module = String.to_existing_atom(module_string)

      # Verify it's a valid routine module by checking for required callbacks
      if Code.ensure_loaded?(module) and function_exported?(module, :initial_context, 0) do
        {:ok, module}
      else
        {:error, "Module #{input} is not a valid routine (missing initial_context/0)"}
      end
    rescue
      ArgumentError ->
        {:error, "Module #{input} not found. Make sure the module is compiled."}
    end
  end

  defp start_routine_session(socket, routine_module) do
    routine_id = "inspector-#{:erlang.unique_integer([:positive])}"

    # Subscribe to routine events
    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

    # Start routine with selected config
    user_context = %{
      llm_provider: socket.assigns.selected_provider,
      llm_model: String.trim(socket.assigns.model_input),
      working_directory: socket.assigns.working_directory,
      system_prompt: socket.assigns.system_prompt,
      enable_llm_logging: true
    }

    case EngineManager.start_routine(routine_id, routine_module, user_context) do
      {:ok, _pid} ->
        Logger.info("Started inspector routine #{routine_id} with #{routine_module}")

        # Get initial lenses from routine
        active_lenses =
          case EngineManager.get_routine(routine_id) do
            {:ok, routine_info} -> routine_info.context[:lenses] || []
            {:error, _} -> []
          end

        socket =
          socket
          |> assign(routine_id: routine_id)
          |> assign(routine_module: routine_module)
          |> assign(status: :running)
          |> assign(active_lenses: active_lenses)

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to start routine: #{inspect(reason)}")
        {:noreply, assign(socket, last_error: "Failed to start: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:new_messages, new_messages}, socket) do
    # Append new messages to existing (the broadcast sends only new messages)
    updated_messages = socket.assigns.messages ++ new_messages
    {:noreply, assign(socket, messages: updated_messages)}
  end

  # Forward user input from ChatPanel to the engine
  def handle_info(
        {:user_input_submitted, %{text: text, images: images, include_screenshot: include_screenshot}},
        socket
      ) do
    Logger.info("Inspector: User input submitted")

    # Build the event data in the format ChatUserInput expects
    data = %{text: text, images: images, include_screenshot: include_screenshot}

    # Include disabled_lenses in context if any are disabled
    # Note: This requires support in the routine/step - for now we just send the input
    Engine.send_external_event(socket.assigns.routine_id, :user_input, data)

    {:noreply, socket}
  end

  # Forward upload check to ChatPanel's UserInputComponent
  def handle_info(:check_uploads, socket) do
    alias WireframeEditorWeb.UserInputComponent
    send_update(UserInputComponent, id: "inspector-chat-panel-input", check_uploads: true)
    {:noreply, socket}
  end

  def handle_info({:clear_sent_feedback, component_id}, socket) do
    alias WireframeEditorWeb.UserInputComponent
    send_update(UserInputComponent, id: component_id, clear_sent_feedback: true)
    {:noreply, socket}
  end

  def handle_info({:routine_event, event}, socket) do
    socket = handle_routine_event(event, socket)
    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp handle_routine_event(%{event_type: "step_started", step_id: step_id}, socket) do
    assign(socket, current_step: step_id)
  end

  defp handle_routine_event(%{event_type: "step_completed"}, socket) do
    socket
  end

  defp handle_routine_event(%{event_type: "context_changed"} = event, socket) do
    # Extract lens_state and rendered context from diff
    context_diff = Map.get(event, :context_diff, []) || []
    Logger.debug("Inspector received context_changed with diff: #{inspect(context_diff, limit: 500)}")

    socket
    |> maybe_update_lens_state(context_diff)
    |> maybe_update_rendered_context(context_diff)
    |> maybe_update_active_lenses(context_diff)
    |> update_token_estimate()
  end

  defp handle_routine_event(%{event_type: "routine_completed"}, socket) do
    assign(socket, status: :completed)
  end

  defp handle_routine_event(%{event_type: "error_occurred", error: error}, socket) do
    assign(socket, status: :error, last_error: error)
  end

  defp handle_routine_event(%{event_type: "llm_request_complete"} = event, socket) do
    # Prepend new log entry (newest first)
    log_entry = %{
      timestamp: Map.get(event, :timestamp, DateTime.utc_now()),
      provider: Map.get(event, :provider),
      model: Map.get(event, :model),
      request: Map.get(event, :request, %{}),
      response: Map.get(event, :response, %{}),
      usage: Map.get(event, :usage)
    }

    assign(socket, llm_log: [log_entry | socket.assigns.llm_log])
  end

  defp handle_routine_event(_event, socket), do: socket

  defp maybe_update_lens_state(socket, diff) do
    new_lens_state = extract_from_diff(diff, [:lens_state, "lens_state"])

    if new_lens_state do
      Logger.debug("Inspector updating lens_state: #{inspect(new_lens_state, limit: 200)}")
      assign(socket, lens_state: new_lens_state)
    else
      socket
    end
  end

  defp maybe_update_rendered_context(socket, diff) do
    new_context = extract_from_diff(diff, [:lens_text_contexts, "lens_text_contexts"])

    if new_context do
      Logger.debug("Inspector updating rendered_context: #{length(new_context)} blocks")
      assign(socket, rendered_context: new_context)
    else
      socket
    end
  end

  defp maybe_update_active_lenses(socket, diff) do
    new_lenses = extract_from_diff(diff, [:lenses, "lenses"])

    if new_lenses do
      Logger.debug("Inspector updating active_lenses: #{inspect(new_lenses)}")
      assign(socket, active_lenses: new_lenses)
    else
      socket
    end
  end

  # Extract a value from diff, handling all possible diff formats
  defp extract_from_diff(diff, keys) when is_list(keys) do
    Enum.reduce_while(diff, nil, fn item, _acc ->
      case extract_value_from_item(item, keys) do
        nil -> {:cont, nil}
        value -> {:halt, value}
      end
    end)
  end

  defp extract_value_from_item(item, keys) do
    map = case item do
      # Tuple format: {:add_or_update, %{...}}
      {:add_or_update, map} when is_map(map) -> map
      {:add, map} when is_map(map) -> map
      {:update, map} when is_map(map) -> map
      # List format with atom: [:add_or_update, %{...}]
      [:add_or_update, map] when is_map(map) -> map
      [:add, map] when is_map(map) -> map
      [:update, map] when is_map(map) -> map
      # List format with string: ["add_or_update", %{...}]
      ["add_or_update", map] when is_map(map) -> map
      ["add", map] when is_map(map) -> map
      ["update", map] when is_map(map) -> map
      _ -> nil
    end

    if map do
      Enum.find_value(keys, fn key -> Map.get(map, key) end)
    else
      nil
    end
  end

  defp update_token_estimate(socket) do
    contexts = socket.assigns.rendered_context

    estimate =
      contexts
      |> Enum.map(&estimate_block_tokens/1)
      |> Enum.sum()

    assign(socket, token_estimate: estimate)
  end

  defp estimate_block_tokens(%{type: "text", text: text}), do: div(String.length(text), 4)
  defp estimate_block_tokens(%{"type" => "text", "text" => text}), do: div(String.length(text), 4)
  defp estimate_block_tokens(%{type: "image"}), do: 1500
  defp estimate_block_tokens(%{"type" => "image"}), do: 1500
  defp estimate_block_tokens(text) when is_binary(text), do: div(String.length(text), 4)
  defp estimate_block_tokens(_), do: 0

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-slate-900 text-white">
      <!-- Header -->
      <header class="flex items-center justify-between px-4 py-2 border-b border-slate-700 bg-slate-800">
        <h1 class="text-lg font-semibold">Koalemos Inspector</h1>
        <div class="flex items-center gap-4">
          <%= if @status != :setup do %>
            <span class="text-sm text-slate-400">
              {short_module_name(@routine_module)} • {@selected_provider}/{@model_input}
            </span>
            <button
              phx-click="reset_session"
              class="px-3 py-1 text-xs bg-slate-700 hover:bg-slate-600 rounded"
            >
              New Session
            </button>
          <% end %>
          <span class="text-sm text-slate-400">
            {status_badge(@status)}
          </span>
          <%= if @current_step do %>
            <span class="text-xs text-slate-500">Step: {@current_step}</span>
          <% end %>
        </div>
      </header>

      <!-- Main content -->
      <div class="flex-1 flex overflow-hidden relative">
        <%= if @status == :setup do %>
          <!-- Setup Panel -->
          <div class="flex-1 flex items-center justify-center">
            <div class="bg-slate-800 rounded-lg p-6 w-[500px] space-y-6">
              <h2 class="text-xl font-semibold text-center">Configure Session</h2>

              <!-- Routine Selection -->
              <div class="space-y-3">
                <label class="block text-sm font-medium text-slate-300">Routine Module</label>
                <form phx-change="routine_form_change" phx-submit="routine_form_change">
                  <input
                    type="text"
                    name="routine_input"
                    value={@routine_input}
                    phx-debounce="100"
                    placeholder="Koalemos.Routines.TestChatRoutine"
                    class="w-full px-3 py-2 rounded-lg font-mono text-sm"
                    style="background-color: #0f172a; border: 1px solid #475569; color: #ffffff;"
                    autocomplete="off"
                    spellcheck="false"
                  />
                </form>
                <div class="text-xs text-slate-400 mb-1">Quick select:</div>
                <div class="flex flex-wrap gap-2">
                  <%= for {module_name, display_name} <- @routine_suggestions do %>
                    <button
                      type="button"
                      phx-click="set_routine"
                      phx-value-routine={module_name}
                      class={[
                        "px-3 py-1.5 rounded border text-sm transition-colors cursor-pointer",
                        if(module_name == @routine_input,
                          do: "bg-blue-600 border-blue-500 text-white",
                          else: "bg-slate-700 border-slate-600 text-slate-300 hover:bg-slate-600"
                        )
                      ]}
                    >
                      {display_name}
                    </button>
                  <% end %>
                </div>
              </div>

              <!-- Provider Selection -->
              <div class="space-y-2">
                <label class="block text-sm font-medium text-slate-300">Provider</label>
                <div class="flex gap-2">
                  <%= for provider <- ["anthropic", "ollama", "openai"] do %>
                    <button
                      type="button"
                      phx-click="set_provider"
                      phx-value-provider={provider}
                      class={[
                        "flex-1 px-4 py-2 rounded-lg border transition-colors font-medium cursor-pointer",
                        if(provider == @selected_provider,
                          do: "bg-blue-600 border-blue-500 text-white",
                          else: "bg-slate-700 border-slate-600 text-slate-200 hover:bg-slate-600"
                        )
                      ]}
                    >
                      {provider}
                    </button>
                  <% end %>
                </div>
              </div>

              <!-- Model Selection -->
              <div class="space-y-3">
                <label class="block text-sm font-medium text-slate-300">Model</label>
                <form phx-change="model_form_change" phx-submit="model_form_change">
                  <input
                    type="text"
                    name="model_input"
                    value={@model_input}
                    phx-debounce="100"
                    placeholder="claude-sonnet-4-5"
                    class="w-full px-3 py-2 rounded-lg font-mono text-sm"
                    style="background-color: #0f172a; border: 1px solid #475569; color: #ffffff;"
                    autocomplete="off"
                    spellcheck="false"
                  />
                </form>
                <div class="text-xs text-slate-400 mb-1">Quick select:</div>
                <div class="flex flex-wrap gap-2">
                  <%= for model <- Map.get(@provider_presets, @selected_provider, []) do %>
                    <button
                      type="button"
                      phx-click="set_model"
                      phx-value-model={model}
                      class={[
                        "px-3 py-1.5 rounded border text-sm transition-colors cursor-pointer",
                        if(model == @model_input,
                          do: "bg-blue-600 border-blue-500 text-white",
                          else: "bg-slate-700 border-slate-600 text-slate-300 hover:bg-slate-600"
                        )
                      ]}
                    >
                      {model}
                    </button>
                  <% end %>
                </div>
              </div>

              <!-- Working Directory -->
              <div class="space-y-2">
                <label class="block text-sm font-medium text-slate-300">Working Directory</label>
                <form phx-change="working_directory_form_change" phx-submit="working_directory_form_change">
                  <input
                    type="text"
                    name="working_directory"
                    value={@working_directory}
                    phx-debounce="100"
                    placeholder="/path/to/project"
                    class="w-full px-3 py-2 rounded-lg font-mono text-sm"
                    style={"background-color: #0f172a; border: 1px solid #{if File.dir?(@working_directory), do: "#475569", else: "#dc2626"}; color: #ffffff;"}
                    autocomplete="off"
                    spellcheck="false"
                  />
                </form>
                <%= unless File.dir?(@working_directory) do %>
                  <div class="text-xs text-red-400">Directory not found</div>
                <% end %>
              </div>

              <!-- System Prompt (for TraditionalAgentRoutine) -->
              <%= if String.contains?(@routine_input, "TraditionalAgentRoutine") do %>
                <div class="space-y-2">
                  <label class="block text-sm font-medium text-slate-300">System Prompt</label>
                  <form phx-change="system_prompt_form_change" phx-submit="system_prompt_form_change">
                    <textarea
                      name="system_prompt"
                      phx-debounce="300"
                      placeholder="Enter system prompt for the agent..."
                      rows="6"
                      class="w-full px-3 py-2 rounded-lg text-sm resize-y"
                      style="background-color: #0f172a; border: 1px solid #475569; color: #ffffff;"
                      spellcheck="false"
                    ><%= @system_prompt %></textarea>
                  </form>
                  <div class="text-xs text-slate-400">
                    This prompt is injected as the agent's system context.
                  </div>
                </div>
              <% end %>

              <!-- Current Selection Summary -->
              <div class="p-3 bg-slate-900 rounded-lg text-sm">
                <div class="text-slate-400">Will start:</div>
                <div class="font-mono text-blue-400 mt-1 break-all">
                  {@routine_input}
                </div>
                <div class="text-slate-400 mt-1">
                  with {@selected_provider}/{@model_input}
                </div>
                <div class="text-slate-400 mt-1">
                  in <span class="font-mono text-green-400">{@working_directory}</span>
                </div>
              </div>

              <!-- Start Button -->
              <button
                phx-click="start_session"
                class="w-full py-3 bg-blue-600 hover:bg-blue-500 rounded-lg font-medium transition-colors"
              >
                Start Session
              </button>

              <%= if @last_error do %>
                <div class="p-3 bg-red-900/50 border border-red-700 rounded text-red-200 text-sm">
                  {@last_error}
                </div>
              <% end %>
            </div>
          </div>
        <% else %>
          <!-- Chat Panel (using WireframeEditorWeb component) -->
          <div class="flex-1 flex flex-col min-w-0 overflow-hidden bg-white text-slate-900">
            <.live_component
              module={ChatPanel}
              id="inspector-chat-panel"
              routine_id={@routine_id}
              messages={@messages}
              current_step={@current_step}
              disabled={@status in [:completed, :error]}
              status={@status}
              last_error={@last_error}
              tool_display={:full}
              show_system_messages={true}
            />
          </div>

          <!-- Inspector Drawer Toggle -->
          <button
            phx-click="toggle_inspector"
            class="absolute right-0 top-1/2 -translate-y-1/2 z-10 bg-slate-700 hover:bg-slate-600 text-slate-300 px-1 py-4 rounded-l-lg border-l border-y border-slate-600 transition-colors"
            style={if @inspector_open, do: "right: #{inspector_width_px(@inspector_width)}px", else: "right: 0"}
          >
            <%= if @inspector_open do %>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            <% else %>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
            <% end %>
          </button>

          <!-- Inspector panel -->
          <div
            class="border-l border-slate-700 flex flex-col bg-slate-800 transition-all duration-200 flex-shrink-0 overflow-hidden"
            style={"width: #{if @inspector_open, do: inspector_width_px(@inspector_width), else: 0}px"}
          >
            <%= if @inspector_open do %>
              <!-- Header with width controls -->
              <div class="flex items-center justify-between px-3 py-2 border-b border-slate-700">
                <span class="text-sm font-medium text-slate-300">Inspector</span>
                <div class="flex gap-1">
                  <button
                    phx-click="set_inspector_width"
                    phx-value-width="w-80"
                    class={["px-2 py-0.5 text-xs rounded", if(@inspector_width == "w-80", do: "bg-blue-600 text-white", else: "bg-slate-700 text-slate-400 hover:bg-slate-600")]}
                  >S</button>
                  <button
                    phx-click="set_inspector_width"
                    phx-value-width="w-96"
                    class={["px-2 py-0.5 text-xs rounded", if(@inspector_width == "w-96", do: "bg-blue-600 text-white", else: "bg-slate-700 text-slate-400 hover:bg-slate-600")]}
                  >M</button>
                  <button
                    phx-click="set_inspector_width"
                    phx-value-width="w-[500px]"
                    class={["px-2 py-0.5 text-xs rounded", if(@inspector_width == "w-[500px]", do: "bg-blue-600 text-white", else: "bg-slate-700 text-slate-400 hover:bg-slate-600")]}
                  >L</button>
                </div>
              </div>

              <!-- Tabs -->
              <div class="flex border-b border-slate-700">
                <button
                  phx-click="switch_tab"
                  phx-value-tab="lenses"
                  class={tab_class(@inspector_tab == :lenses)}
                >
                  Lenses
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="context"
                  class={tab_class(@inspector_tab == :context)}
                >
                  Context
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="state"
                  class={tab_class(@inspector_tab == :state)}
                >
                  State
                </button>
                <button
                  phx-click="switch_tab"
                  phx-value-tab="log"
                  class={tab_class(@inspector_tab == :log)}
                >
                  Log
                  <%= if length(@llm_log) > 0 do %>
                    <span class="ml-1 px-1.5 py-0.5 text-xs bg-blue-600 rounded-full">{length(@llm_log)}</span>
                  <% end %>
                </button>
              </div>

              <!-- Tab content -->
              <div class="flex-1 overflow-auto p-3 min-h-0 min-w-0">
                <%= case @inspector_tab do %>
                  <% :lenses -> %>
                    <.lenses_tab
                      active_lenses={@active_lenses}
                      disabled_lenses={@disabled_lenses}
                    />
                  <% :context -> %>
                    <.context_tab rendered_context={@rendered_context} />
                  <% :state -> %>
                    <.state_tab lens_state={@lens_state} />
                  <% :log -> %>
                    <.log_tab llm_log={@llm_log} />
                <% end %>
              </div>

              <!-- Footer -->
              <div class="border-t border-slate-700 px-3 py-2 text-xs text-slate-400">
                <div class="flex justify-between">
                  <span>Est. Context Tokens:</span>
                  <span class="font-mono text-blue-400">{format_number(@token_estimate)}</span>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Components

  defp lenses_tab(assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="text-xs text-slate-400 uppercase tracking-wide">Active Lenses</div>
      <%= for lens <- @active_lenses do %>
        <div class="bg-slate-700 rounded p-2">
          <div class="flex items-center justify-between">
            <span class="text-sm font-mono truncate">{short_lens_name(lens)}</span>
            <button
              phx-click="toggle_lens"
              phx-value-lens={lens_key(lens)}
              class={[
                "text-xs px-2 py-1 rounded",
                if(lens_key(lens) in @disabled_lenses,
                  do: "bg-red-900 text-red-300",
                  else: "bg-green-900 text-green-300"
                )
              ]}
            >
              {if lens_key(lens) in @disabled_lenses, do: "Disabled", else: "Enabled"}
            </button>
          </div>
        </div>
      <% end %>
      <%= if @active_lenses == [] do %>
        <div class="text-sm text-slate-500 italic">No lenses configured</div>
      <% end %>
    </div>
    """
  end

  defp context_tab(assigns) do
    ~H"""
    <div class="space-y-3 min-w-0">
      <div class="text-xs text-slate-400 uppercase tracking-wide">Rendered Context</div>
      <%= for {block, idx} <- Enum.with_index(@rendered_context) do %>
        <div class="bg-slate-700 rounded p-2 overflow-hidden">
          <div class="text-xs text-slate-500 mb-1">Block {idx + 1}</div>
          <pre class="text-xs text-slate-300 whitespace-pre-wrap break-all overflow-auto max-h-40">{format_context_block(block)}</pre>
        </div>
      <% end %>
      <%= if @rendered_context == [] do %>
        <div class="text-sm text-slate-500 italic">No context rendered yet</div>
      <% end %>
    </div>
    """
  end

  defp state_tab(assigns) do
    ~H"""
    <div class="space-y-3 min-w-0">
      <div class="text-xs text-slate-400 uppercase tracking-wide">Lens State</div>
      <div class="bg-slate-700 rounded p-2 overflow-hidden">
        <pre class="text-xs text-slate-300 whitespace-pre-wrap break-all overflow-auto max-h-[60vh]">{format_lens_state(@lens_state)}</pre>
      </div>
    </div>
    """
  end

  defp log_tab(assigns) do
    ~H"""
    <div class="space-y-3 min-w-0">
      <div class="text-xs text-slate-400 uppercase tracking-wide">LLM Request Log</div>
      <%= for {entry, idx} <- Enum.with_index(@llm_log) do %>
        <details class="bg-slate-700 rounded overflow-hidden" open={idx == 0}>
          <summary class="px-3 py-2 cursor-pointer hover:bg-slate-600 flex items-center justify-between">
            <div class="flex items-center gap-2">
              <span class="text-xs text-slate-500">#{length(@llm_log) - idx}</span>
              <span class="text-sm font-mono">{entry.provider}/{entry.model}</span>
            </div>
            <div class="text-xs text-slate-400">
              <%= if entry.usage do %>
                {entry.usage[:input_tokens] || entry.usage["input_tokens"]}→{entry.usage[:output_tokens] || entry.usage["output_tokens"]} tokens
              <% end %>
            </div>
          </summary>
          <div class="px-3 py-2 border-t border-slate-600 space-y-2">
            <!-- System Blocks -->
            <details class="bg-slate-800 rounded">
              <summary class="px-2 py-1 cursor-pointer hover:bg-slate-700 text-xs text-slate-400">
                System Blocks ({length(get_in(entry, [:request, :system_blocks]) || [])})
              </summary>
              <div class="p-2 space-y-2">
                <%= for {block, bidx} <- Enum.with_index(get_in(entry, [:request, :system_blocks]) || []) do %>
                  <details class="bg-slate-900 rounded">
                    <summary class="px-2 py-1 cursor-pointer hover:bg-slate-800 text-xs text-slate-500">
                      {bidx + 1}. {block[:type] || block["type"]} ({String.length(block[:text] || block["text"] || "")} chars)
                    </summary>
                    <pre class="text-xs text-slate-300 whitespace-pre-wrap break-all p-2 max-h-60 overflow-auto">{block[:text] || block["text"]}</pre>
                  </details>
                <% end %>
              </div>
            </details>

            <!-- Tools -->
            <details class="bg-slate-800 rounded">
              <summary class="px-2 py-1 cursor-pointer hover:bg-slate-700 text-xs text-slate-400">
                Tools ({length(get_in(entry, [:request, :tools]) || [])})
              </summary>
              <div class="p-2 space-y-1">
                <%= for tool <- get_in(entry, [:request, :tools]) || [] do %>
                  <div class="text-xs">
                    <span class="text-blue-400 font-mono">{tool[:name] || tool["name"]}</span>
                    <span class="text-slate-500 ml-2">{tool[:description] || tool["description"]}</span>
                  </div>
                <% end %>
                <%= if (get_in(entry, [:request, :tools]) || []) == [] do %>
                  <div class="text-xs text-slate-500 italic">No tools</div>
                <% end %>
              </div>
            </details>

            <!-- Messages -->
            <details class="bg-slate-800 rounded">
              <summary class="px-2 py-1 cursor-pointer hover:bg-slate-700 text-xs text-slate-400">
                Messages ({length(get_in(entry, [:request, :messages]) || [])})
              </summary>
              <div class="p-2 space-y-2">
                <%= for {msg, midx} <- Enum.with_index(get_in(entry, [:request, :messages]) || []) do %>
                  <details class="bg-slate-900 rounded">
                    <summary class="px-2 py-1 cursor-pointer hover:bg-slate-800 text-xs text-slate-500">
                      {midx + 1}. {msg[:role] || msg["role"]}
                    </summary>
                    <pre class="text-xs text-slate-300 whitespace-pre-wrap break-all p-2 max-h-40 overflow-auto">{format_message_content(msg[:content] || msg["content"])}</pre>
                  </details>
                <% end %>
              </div>
            </details>

            <!-- Response -->
            <details class="bg-slate-800 rounded" open>
              <summary class="px-2 py-1 cursor-pointer hover:bg-slate-700 text-xs text-slate-400">
                Response
              </summary>
              <div class="p-2 space-y-2">
                <%= for {block, ridx} <- Enum.with_index(entry.response[:content] || entry.response["content"] || []) do %>
                  <details class="bg-slate-900 rounded" open={ridx == 0}>
                    <summary class="px-2 py-1 cursor-pointer hover:bg-slate-800 text-xs text-slate-500">
                      {ridx + 1}. {block["type"] || block[:type]}
                      <%= if (block["type"] || block[:type]) == "tool_use" do %>
                        <span class="text-blue-400 ml-1">{block["name"] || block[:name]}</span>
                      <% end %>
                    </summary>
                    <pre class="text-xs text-slate-300 whitespace-pre-wrap break-all p-2 max-h-40 overflow-auto">{format_response_block(block)}</pre>
                  </details>
                <% end %>
                <%= if entry.response[:error] do %>
                  <div class="text-xs text-red-400 p-2">{entry.response[:error]}</div>
                <% end %>
                <%= if (entry.response[:content] || entry.response["content"] || []) == [] and not Map.has_key?(entry.response, :error) do %>
                  <div class="text-xs text-slate-500 italic p-2">No response content</div>
                <% end %>
              </div>
            </details>
          </div>
        </details>
      <% end %>
      <%= if @llm_log == [] do %>
        <div class="text-sm text-slate-500 italic">No LLM requests yet</div>
      <% end %>
    </div>
    """
  end

  # Helpers

  defp tab_class(active?) do
    base = "flex-1 px-3 py-2 text-sm font-medium text-center transition-colors"

    if active? do
      "#{base} text-blue-400 border-b-2 border-blue-400"
    else
      "#{base} text-slate-400 hover:text-slate-200"
    end
  end

  defp status_badge(:setup), do: "Setup"
  defp status_badge(:running), do: "Running"
  defp status_badge(:completed), do: "Completed"
  defp status_badge(:error), do: "Error"

  defp short_module_name(nil), do: "Unknown"

  defp short_module_name(module) when is_atom(module) do
    module
    |> Module.split()
    |> List.last()
  end

  defp short_lens_name(lens) when is_binary(lens) do
    lens |> String.split(".") |> List.last()
  end

  defp short_lens_name([name | _]) when is_binary(name) do
    name |> String.split(".") |> List.last()
  end

  defp short_lens_name(_), do: "Unknown"

  defp lens_key(lens) when is_binary(lens), do: lens
  defp lens_key([name | _]), do: name
  defp lens_key(_), do: ""

  defp format_context_block(%{type: "text", text: text}), do: truncate(text, 500)
  defp format_context_block(%{"type" => "text", "text" => text}), do: truncate(text, 500)
  defp format_context_block(%{type: "image"}), do: "[Image]"
  defp format_context_block(%{"type" => "image"}), do: "[Image]"
  defp format_context_block(text) when is_binary(text), do: truncate(text, 500)
  defp format_context_block(other), do: inspect(other, limit: 100)

  defp format_lens_state(state) when state == %{}, do: "{}"

  defp format_lens_state(state) do
    Jason.encode!(state, pretty: true)
  rescue
    _ -> inspect(state, pretty: true, limit: 500)
  end

  defp truncate(text, max_length) when is_binary(text) and byte_size(text) > max_length do
    String.slice(text, 0, max_length) <> "..."
  end

  defp truncate(text, _) when is_binary(text), do: text
  defp truncate(_, _), do: ""

  defp format_message_content(content) when is_binary(content), do: content

  defp format_message_content(content) when is_list(content) do
    content
    |> Enum.map(fn block ->
      case block do
        %{"type" => "text", "text" => text} -> text
        %{type: "text", text: text} -> text
        %{"type" => "tool_use", "name" => name, "input" => input} ->
          "[tool_use: #{name}]\n#{Jason.encode!(input, pretty: true)}"
        %{"type" => "tool_result", "content" => result} ->
          "[tool_result]\n#{inspect(result, limit: 200)}"
        _ -> inspect(block, limit: 100)
      end
    end)
    |> Enum.join("\n\n")
  end

  defp format_message_content(other), do: inspect(other, limit: 200)

  defp format_response_block(block) when is_map(block) do
    type = block["type"] || block[:type]

    case type do
      "text" -> block["text"] || block[:text] || ""
      "tool_use" ->
        input = block["input"] || block[:input] || %{}
        try do
          Jason.encode!(input, pretty: true)
        rescue
          _ -> inspect(input, pretty: true)
        end
      _ -> inspect(block, pretty: true, limit: 500)
    end
  end

  defp format_response_block(other), do: inspect(other, limit: 200)

  defp format_number(n) when n >= 1000 do
    "#{div(n, 1000)}k"
  end

  defp format_number(n), do: to_string(n)

  defp inspector_width_px("w-80"), do: 320
  defp inspector_width_px("w-96"), do: 384
  defp inspector_width_px("w-[500px]"), do: 500
  defp inspector_width_px(_), do: 384
end
