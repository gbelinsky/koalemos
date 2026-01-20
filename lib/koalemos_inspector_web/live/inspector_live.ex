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
  import WireframeEditorWeb.MarkdownHelper

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
    "Koalemos.Routines.TraditionalAgentRoutine" => "Traditional Agent",
    "Koalemos.Routines.ContextAgentRoutine" => "Context Agent"
  }

  @default_system_prompt "You are a software engineer. Help with coding tasks using the available tools."

  @impl true
  def mount(params, _session, socket) do
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
        llm_log: [],
        # Retrospective state
        retrospective_id: nil,
        retrospective_status: :idle,
        retrospective_results: [],
        retrospective_error: nil,
        # Extraction state
        extraction_id: nil,
        extraction_status: :idle,
        extracted_insights: []
      )

    # Check if we should attach to an existing routine
    socket =
      case Map.get(params, "routine_id") do
        nil -> socket
        routine_id -> attach_to_routine(socket, routine_id)
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Handle URL parameter changes (e.g., from push_patch)
    # Mount already handles initial attachment, so just update if needed
    socket =
      case Map.get(params, "routine_id") do
        nil ->
          socket

        routine_id when routine_id == socket.assigns.routine_id ->
          # Already attached to this routine, no change needed
          socket

        routine_id ->
          # New routine_id in URL, attach to it
          attach_to_routine(socket, routine_id)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_routine", %{"routine" => routine}, socket) do
    Logger.debug("set_routine: #{routine}")

    # Update system prompt based on routine
    system_prompt = cond do
      String.contains?(routine, "ContextAgentRoutine") ->
        """
        You are a software engineer with context-aware file management.

        ## File Management Strategy

        - Use 'open' to add files/directories to your working context
        - Open files stay visible and auto-update after edits
        - Use 'close' to remove files when done
        - Maximum 10 open files at once

        ## Tool Workflow

        1. **Explore**: Use Glob/Grep to find relevant files
        2. **Open**: Add files to context with 'open' (content appears automatically)
        3. **Edit**: Modify open files with 'edit' (only works on open files)
        4. **Write**: Create new files with 'write' (auto-opens them)
        5. **Close**: Remove files from context when finished

        ## Important

        - Unlike traditional agents, you don't need to Read files repeatedly
        - Open files are always visible in your context
        - After editing, the updated content appears automatically (no re-reading needed)
        - You must 'open' files before you can 'edit' them (parallel to "Read before Edit")

        Help with coding tasks using the available tools.
        """
      String.contains?(routine, "TraditionalAgentRoutine") ->
        "You are a software engineer. Help with coding tasks using the available tools."
      true ->
        @default_system_prompt
    end

    {:noreply, assign(socket, routine_input: routine, system_prompt: system_prompt)}
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
    tab_atom =
      case tab do
        "lenses" -> :lenses
        "context" -> :context
        "state" -> :state
        "log" -> :log
        "retrospective" -> :retrospective
        _ -> :lenses
      end

    {:noreply, assign(socket, inspector_tab: tab_atom)}
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
    # Unsubscribe from retrospective if active
    if socket.assigns.retrospective_id do
      Phoenix.PubSub.unsubscribe(Koalemos.PubSub, "routine:#{socket.assigns.retrospective_id}")
    end

    # Unsubscribe from extraction if active
    if socket.assigns.extraction_id do
      Phoenix.PubSub.unsubscribe(Koalemos.PubSub, "routine:#{socket.assigns.extraction_id}")
    end

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
        llm_log: [],
        # Retrospective resets
        retrospective_id: nil,
        retrospective_status: :idle,
        retrospective_results: [],
        retrospective_error: nil,
        # Extraction resets
        extraction_id: nil,
        extraction_status: :idle,
        extracted_insights: []
      )

    {:noreply, socket}
  end

  def handle_event("trigger_retrospective", _params, socket) do
    routine_id = socket.assigns.routine_id

    if routine_id do
      # Generate unique ID for retrospective routine
      retro_id = "retrospective-#{:erlang.unique_integer([:positive])}"

      # Subscribe to retrospective events
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{retro_id}")

      # Start retrospective routine with source_routine_id
      user_context = %{
        source_routine_id: routine_id
      }

      case EngineManager.start_routine(
             retro_id,
             Koalemos.Routines.RetrospectiveRoutine,
             user_context
           ) do
        {:ok, _pid} ->
          {:noreply,
           socket
           |> assign(retrospective_id: retro_id)
           |> assign(retrospective_status: :running)
           |> assign(retrospective_error: nil)}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(retrospective_status: :error)
           |> assign(retrospective_error: "Failed to start: #{inspect(reason)}")}
      end
    else
      {:noreply, assign(socket, last_error: "No active routine to analyze")}
    end
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
          |> push_patch(to: "/#{routine_id}")

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to start routine: #{inspect(reason)}")
        {:noreply, assign(socket, last_error: "Failed to start: #{inspect(reason)}")}
    end
  end

  defp attach_to_routine(socket, routine_id) do
    Logger.info("Attempting to attach to routine: #{routine_id}")

    case EngineManager.get_routine(routine_id) do
      {:ok, routine_info} ->
        Logger.info("Successfully found routine #{routine_id}, attaching...")

        # Subscribe to routine events
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

        # Extract config from context for display
        context = routine_info.context || %{}
        
        socket
        |> assign(routine_id: routine_id)
        |> assign(routine_module: routine_info.module)
        |> assign(status: routine_info.status)
        |> assign(messages: routine_info.messages)
        |> assign(lens_state: routine_info.lens_state)
        |> assign(active_lenses: context[:lenses] || [])
        |> assign(current_step: routine_info.current_step)
        |> assign(selected_provider: context[:llm_provider] || "anthropic")
        |> assign(model_input: context[:llm_model] || "claude-sonnet-4-5")
        |> assign(working_directory: context[:working_directory] || File.cwd!())
        |> assign(system_prompt: context[:system_prompt] || @default_system_prompt)
        |> assign(extraction_id: nil)
        |> assign(extraction_status: :idle)
        |> assign(extracted_insights: [])

      {:error, :not_found} ->
        Logger.warning("Routine #{routine_id} not found, staying in setup mode")
        assign(socket, last_error: "Routine #{routine_id} not found. Starting fresh session.")
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
    routine_id = Map.get(event, :routine_id)

    socket =
      cond do
        # Extraction event
        routine_id == socket.assigns.extraction_id ->
          handle_extraction_event(event, socket)

        # Retrospective event
        routine_id == socket.assigns.retrospective_id ->
          handle_retrospective_event(event, socket)

        # Main routine event (existing behavior)
        routine_id == socket.assigns.routine_id ->
          handle_routine_event(event, socket)

        # Unknown routine, ignore
        true ->
          socket
      end

    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp handle_retrospective_event(%{event_type: "routine_completed"} = event, socket) do
    # Extract context from event metadata
    context = get_in(event, [:metadata, :final_context]) || %{}
    
    # Extract knowledge_document from context
    # StructuredResponseAgent stores output in context[:structured_output][field_name]
    knowledge_doc =
      get_in(context, [:structured_output, "knowledge_document"]) ||
        get_in(context, [:structured_output, :knowledge_document]) ||
        get_in(context, [:knowledge_document]) ||
        get_in(context, ["knowledge_document"])

    # Debug logging
    Logger.info("Retrospective completed. Context keys: #{inspect(Map.keys(context))}")
    Logger.info("Structured output: #{inspect(get_in(context, [:structured_output]))}")
    Logger.info("Knowledge doc found: #{!is_nil(knowledge_doc)}")

    retro_id = socket.assigns.retrospective_id

    # Add to results list
    result = {retro_id, knowledge_doc || "No knowledge document generated"}
    updated_results = socket.assigns.retrospective_results ++ [result]

    socket =
      socket
      |> assign(retrospective_status: :completed)
      |> assign(retrospective_results: updated_results)
      |> assign(inspector_tab: :retrospective)

    # Automatically start knowledge extraction if we have a document
    if knowledge_doc && knowledge_doc != "" do
      start_knowledge_extraction(socket, retro_id, knowledge_doc)
    else
      socket
    end
  end

  defp handle_retrospective_event(%{event_type: "error_occurred"} = event, socket) do
    error_msg = Map.get(event, :error, "Unknown error")
    
    Logger.error("Retrospective error: #{inspect(error_msg)}")
    Logger.error("Full event: #{inspect(event, pretty: true)}")

    socket
    |> assign(retrospective_status: :error)
    |> assign(retrospective_error: error_msg)
  end

  defp handle_retrospective_event(%{event_type: "step_started"}, socket) do
    # Just tracking, no UI updates needed
    socket
  end

  defp handle_retrospective_event(event, socket) do
    # Log unknown events for debugging
    Logger.debug("Retrospective event (#{event[:event_type]}): #{inspect(event, pretty: true, limit: 3)}")
    socket
  end

  # Knowledge Extraction Event Handlers

  defp start_knowledge_extraction(socket, retro_id, knowledge_doc) do
    # Generate unique ID for extraction routine
    extract_id = "extraction-#{:erlang.unique_integer([:positive])}"

    Logger.info("Starting knowledge extraction routine: #{extract_id}")

    # Subscribe to extraction events
    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{extract_id}")

    # Start extraction routine with knowledge document
    user_context = %{
      source_retrospective_id: retro_id,
      messages: [
        %{
          role: "user",
          content: """
          Please extract discrete, actionable insights from the following retrospective analysis.

          # Retrospective Document

          #{knowledge_doc}

          Extract insights following the guidelines provided in your system prompt.
          """
        }
      ]
    }

    case EngineManager.start_routine(
           extract_id,
           Koalemos.Routines.KnowledgeExtractionRoutine,
           user_context
         ) do
      {:ok, _pid} ->
        Logger.info("Knowledge extraction started: #{extract_id}")
        socket
        |> assign(extraction_id: extract_id)
        |> assign(extraction_status: :running)
        |> assign(extracted_insights: [])

      {:error, reason} ->
        Logger.error("Failed to start extraction: #{inspect(reason)}")
        socket
        |> assign(extraction_status: :error)
    end
  end

  defp handle_extraction_event(%{event_type: "routine_completed"} = event, socket) do
    # Extract insights from context
    context = get_in(event, [:metadata, :final_context]) || %{}
    
    insights =
      get_in(context, [:structured_output, "insights"]) ||
        get_in(context, [:structured_output, :insights]) ||
        []

    Logger.info("Extraction completed. Found #{length(insights)} insights")

    socket
    |> assign(extraction_status: :completed)
    |> assign(extracted_insights: insights)
  end

  defp handle_extraction_event(%{event_type: "error_occurred"} = event, socket) do
    error_msg = get_in(event, [:metadata, :error]) || "Unknown error"
    Logger.error("Extraction error: #{inspect(error_msg)}")

    socket
    |> assign(extraction_status: :error)
  end

  defp handle_extraction_event(%{event_type: "step_started"}, socket) do
    # Keep status as :running
    socket
  end

  defp handle_extraction_event(event, socket) do
    # Log unknown events for debugging
    Logger.debug("Extraction event (#{event[:event_type]}): #{inspect(event, pretty: true, limit: 3)}")
    socket
  end

  # Main Routine Event Handlers

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
            <%= if @routine_id && @status in [:running, :completed, :error] do %>
              <button
                phx-click="trigger_retrospective"
                disabled={@retrospective_status == :running}
                class={"px-3 py-1 text-xs rounded transition #{
                  if @retrospective_status == :running do
                    "bg-slate-600 text-slate-400 cursor-not-allowed"
                  else
                    "bg-purple-600 text-white hover:bg-purple-700"
                  end
                }"}
              >
                <%= if @retrospective_status == :running do %>
                  <div class="flex items-center gap-2">
                    <svg class="animate-spin h-3 w-3" fill="none" viewBox="0 0 24 24">
                      <circle
                        class="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="4"
                      >
                      </circle>
                      <path
                        class="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      >
                      </path>
                    </svg>
                    <span>Analyzing...</span>
                  </div>
                <% else %>
                  Run Retrospective
                <% end %>
              </button>
            <% end %>
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

              <!-- System Prompt (for TraditionalAgentRoutine and ContextAgentRoutine) -->
              <%= if String.contains?(@routine_input, "TraditionalAgentRoutine") or String.contains?(@routine_input, "ContextAgentRoutine") do %>
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
                <button
                  phx-click="switch_tab"
                  phx-value-tab="retrospective"
                  class={tab_class(@inspector_tab == :retrospective)}
                >
                  Retrospective
                  <%= if length(@retrospective_results) > 0 do %>
                    <span class="ml-1 px-1.5 py-0.5 text-xs bg-purple-100 text-purple-700 rounded-full">
                      {length(@retrospective_results)}
                    </span>
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

                  <% :retrospective -> %>
                    <.retrospective_tab
                      retrospective_status={@retrospective_status}
                      retrospective_error={@retrospective_error}
                      retrospective_results={@retrospective_results}
                      extraction_status={@extraction_status}
                      extraction_id={@extraction_id}
                      extracted_insights={@extracted_insights}
                    />
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

  defp retrospective_tab(assigns) do
    ~H"""
    <div class="p-4 space-y-4">
      <%= if @retrospective_status == :running do %>
        <!-- Running State -->
        <div class="flex items-center gap-3 p-4 bg-purple-50 border border-purple-200 rounded-lg">
          <svg class="animate-spin h-5 w-5 text-purple-600" fill="none" viewBox="0 0 24 24">
            <circle
              class="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              stroke-width="4"
            >
            </circle>
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            >
            </path>
          </svg>
          <span class="text-sm text-purple-700">Running retrospective analysis...</span>
        </div>
      <% end %>
      <%= if @retrospective_status == :error do %>
        <!-- Error State -->
        <div class="p-4 bg-red-50 border border-red-200 rounded-lg">
          <h3 class="text-sm font-semibold text-red-900 mb-1">Error</h3>
          <p class="text-sm text-red-700">{@retrospective_error}</p>
        </div>
      <% end %>
      <%= if Enum.empty?(@retrospective_results) && @retrospective_status == :idle do %>
        <!-- Empty State -->
        <div class="text-center py-8">
          <svg
            class="mx-auto h-12 w-12 text-slate-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
            />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-slate-900">No retrospectives yet</h3>
          <p class="mt-1 text-sm text-slate-500">
            Click "Run Retrospective" to analyze the current routine
          </p>
        </div>
      <% end %>
      <!-- Results List (newest first) -->
      <%= for {retro_id, knowledge_doc} <- Enum.reverse(@retrospective_results) do %>
        <div class="border border-slate-200 rounded-lg overflow-hidden">
          <div class="bg-slate-50 px-4 py-2 border-b border-slate-200">
            <h3 class="text-xs font-medium text-slate-700">
              Retrospective: {retro_id}
            </h3>
          </div>
          <div class="p-4 bg-white">
            <!-- Use markdown helper for rendering -->
            <div class="prose prose-sm max-w-none
                        prose-p:my-2 prose-p:leading-relaxed prose-p:text-slate-700
                        prose-ul:my-2 prose-ul:list-disc prose-ul:pl-5
                        prose-ol:my-2 prose-ol:list-decimal prose-ol:pl-5
                        prose-li:my-1
                        prose-code:bg-slate-100 prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded prose-code:text-xs prose-code:text-slate-800
                        prose-pre:bg-slate-900 prose-pre:p-3 prose-pre:rounded-lg prose-pre:my-3
                        [&_pre_code]:text-slate-100 [&_pre_code]:bg-transparent [&_pre_code]:p-0
                        prose-h1:text-base prose-h1:font-bold prose-h1:mt-4 prose-h1:mb-2 prose-h1:text-slate-900
                        prose-h2:text-sm prose-h2:font-bold prose-h2:mt-3 prose-h2:mb-1.5 prose-h2:text-slate-900
                        prose-h3:text-sm prose-h3:font-semibold prose-h3:mt-2 prose-h3:mb-1 prose-h3:text-slate-800
                        prose-blockquote:border-l-4 prose-blockquote:border-slate-300 prose-blockquote:pl-4 prose-blockquote:italic">
              {safe_markdown_to_html(knowledge_doc, skip_wrapper: true)}
            </div>
          </div>
        </div>
      <% end %>
      <!-- Extraction Status -->
      <%= if @extraction_status == :running do %>
        <div class="flex items-center gap-3 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <svg class="animate-spin h-5 w-5 text-blue-600" fill="none" viewBox="0 0 24 24">
            <circle
              class="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              stroke-width="4"
            >
            </circle>
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            >
            </path>
          </svg>
          <span class="text-sm text-blue-700">Extracting insights from retrospective...</span>
        </div>
      <% end %>
      <%= if @extraction_status == :error do %>
        <div class="p-4 bg-red-50 border border-red-200 rounded-lg">
          <h3 class="text-sm font-semibold text-red-900 mb-1">Extraction Error</h3>
          <p class="text-sm text-red-700">Failed to extract insights from retrospective</p>
        </div>
      <% end %>
      <!-- Extracted Insights -->
      <%= if @extraction_status == :completed && !Enum.empty?(@extracted_insights) do %>
        <div class="border border-emerald-200 rounded-lg overflow-hidden bg-emerald-50">
          <div class="bg-emerald-100 px-4 py-2 border-b border-emerald-200">
            <h3 class="text-sm font-semibold" style="color: #064e3b;">
              🎯 Extracted Insights ({length(@extracted_insights)})
            </h3>
            <p class="text-xs mt-0.5" style="color: #047857;">
              Atomic, actionable knowledge units from the retrospective
            </p>
          </div>
          <div class="p-4 space-y-3">
            <%= for insight <- @extracted_insights do %>
              <.insight_card insight={insight} />
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp insight_card(assigns) do
    ~H"""
    <div class="bg-white border border-slate-200 rounded-lg p-4 shadow-sm hover:shadow-md transition-shadow">
      <!-- Domain Badge and Section -->
      <div class="flex items-start justify-between mb-3">
        <span class="inline-flex items-center px-2.5 py-1 rounded-md text-xs font-semibold bg-blue-100 border border-blue-200" style="color: #1e40af;">
          🏷️ {Map.get(@insight, "domain", "general")}
        </span>
        <span class="text-xs italic" style="color: #64748b;">
          {Map.get(@insight, "section", "")}
        </span>
      </div>
      
      <!-- Summary -->
      <h4 class="text-sm font-semibold mb-3 leading-relaxed" style="color: #0f172a;">
        {Map.get(@insight, "summary", "")}
      </h4>
      
      <!-- Reminder (yellow sticky note style with explicit colors) -->
      <div class="mb-3 p-3 rounded-md" style="background-color: #fef3c7; border: 1px solid #fbbf24;">
        <p class="text-sm leading-relaxed" style="color: #78350f;">
          <span class="font-bold">💡 Reminder:</span>
          <span class="ml-1">{Map.get(@insight, "reminder", "")}</span>
        </p>
      </div>
      
      <!-- Applies When -->
      <div class="text-sm leading-relaxed" style="color: #334155;">
        <span class="font-semibold" style="color: #0f172a;">📍 Applies when:</span>
        <span class="ml-1">{Map.get(@insight, "applies_when", "")}</span>
      </div>
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
