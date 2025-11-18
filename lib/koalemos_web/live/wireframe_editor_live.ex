defmodule KoalemosWeb.WireframeEditorLive do
  @moduledoc """
  Production wireframe editor page for M6 demo.

  Clean, polished interface for building and modifying wireframes through conversation.
  Based on WireframeTestLive but with debug UI removed for production use.

  Features:
  - Sample wireframe selection or HTML upload
  - Auto-starts WireframeDesignRoutine
  - Split-screen layout: Chat (40%) + Live Preview (60%)
  - Resizable panels
  - Save/export functionality
  - Production defaults (inline tools, hide system messages)

  Route: /wireframe-editor
  """
  use KoalemosWeb, :live_view
  require Logger

  alias Koalemos.Integrations.ParsingIntegration
  alias Koalemos.Lenses.WireframeEditor
  alias Koalemos.{EngineManager, Engine}
  alias Koalemos.Routines.WireframeDesignRoutine
  alias KoalemosWeb.ChatPanel

  @available_samples [
    {"simple", "Simple Login Form", "wireframe_simple.html",
     "A basic login form with email and password fields"},
    {"medium", "Dashboard Layout", "wireframe_medium.html",
     "Multi-section dashboard with navigation and content areas"},
    {"complex", "E-commerce Page", "wireframe_complex.html",
     "Full product page with images, details, and shopping cart"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Wireframe Editor",
       # Sample selection state
       show_sample_modal: true,
       available_samples: @available_samples,
       current_sample: nil,
       loaded_html: nil,
       # Routine state
       routine_id: nil,
       messages: [],
       status: :idle,
       current_step: nil,
       routine_module: nil,
       execution_stack: [],
       step_module: nil,
       last_error: nil,
       agent_running: false,
       # Wireframe state
       lens_state: nil,
       # UI state
       left_panel_width: 40,
       # Fixed display options (production defaults)
       tool_display: :inline,
       show_system_messages: false
     )
     |> allow_upload(:html_file,
       accept: ~w(.html .htm),
       max_entries: 1,
       max_file_size: 1_000_000,
       auto_upload: true
     ), layout: false}
  end

  @impl true
  def handle_event("select_sample", %{"sample" => sample_id}, socket) do
    Logger.info("[WireframeEditor] Loading sample: #{sample_id}")

    case load_sample_html(sample_id) do
      {:ok, html_content} ->
        sample_name = get_sample_name(sample_id)

        # Generate unique routine_id for this session
        routine_id = "wireframe-editor-#{:erlang.unique_integer([:positive])}"

        # Parse HTML and create lens state
        {lens_state, _agent_context} = parse_and_create_lens_state(html_content)

        # Store lens_state in cache for preview
        if lens_state do
          Koalemos.Caches.WireframeStateCache.put_state(routine_id, lens_state)

          # Broadcast initial DOM tree
          dom_tree = get_in(lens_state, [:designed, :dom_tree])

          Phoenix.PubSub.broadcast(
            Koalemos.PubSub,
            "wireframe_updates:#{routine_id}",
            {:dom_tree_updated, dom_tree, %{source: :initial_load}}
          )
        end

        # Subscribe to routine events
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
          Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")
        end

        # Auto-start WireframeDesignRoutine with this sample
        user_context = %{
          routine_id: routine_id,
          llm_provider: "anthropic",
          llm_model: "claude-sonnet-4-5",
          max_tokens: 64000,
          temperature: 0.7,
          wireframe_html: html_content
        }

        case EngineManager.start_routine(routine_id, WireframeDesignRoutine, user_context) do
          {:ok, _pid} ->
            Logger.info(
              "[WireframeEditor] Started WireframeDesignRoutine #{routine_id} with sample #{sample_id}"
            )

            {:noreply,
             assign(socket,
               routine_id: routine_id,
               loaded_html: html_content,
               current_sample: sample_name,
               lens_state: lens_state,
               show_sample_modal: false,
               agent_running: true,
               status: :running,
               messages: [],
               last_error: nil
             )}

          {:error, reason} ->
            Logger.error(
              "[WireframeEditor] Failed to start routine #{routine_id}: #{inspect(reason)}"
            )

            {:noreply,
             assign(socket,
               last_error: "Failed to start routine: #{inspect(reason)}"
             )}
        end

      {:error, reason} ->
        Logger.error("[WireframeEditor] Failed to load sample #{sample_id}: #{inspect(reason)}")

        {:noreply,
         assign(socket,
           last_error: "Failed to load sample: #{reason}"
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"_target" => ["html_file"]} = _params, socket) do
    # File selected - start polling for upload completion
    Process.send_after(self(), :check_uploads, 500)
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :html_file, ref)}
  end

  @impl true
  def handle_event("new_wireframe", _params, socket) do
    # Stop current routine if running
    if socket.assigns.routine_id && socket.assigns.agent_running do
      EngineManager.stop_routine(socket.assigns.routine_id)
    end

    {:noreply,
     assign(socket,
       show_sample_modal: true,
       routine_id: nil,
       loaded_html: nil,
       current_sample: nil,
       lens_state: nil,
       messages: [],
       status: :idle,
       agent_running: false,
       last_error: nil
     )}
  end

  @impl true
  def handle_event("save_wireframe", _params, socket) do
    Logger.info("[WireframeEditor] Generating wireframe download")

    case socket.assigns[:routine_id] do
      nil ->
        {:noreply, socket}

      routine_id ->
        # Get the designed state from cache
        wireframe_state = Koalemos.Caches.WireframeStateCache.get_state(routine_id)

        if wireframe_state do
          # Generate complete HTML from designed state
          try do
            html = generate_wireframe_html(wireframe_state)
            Logger.info("[WireframeEditor] Generated HTML, length: #{String.length(html)} chars")
            filename = "wireframe_#{routine_id}_#{DateTime.utc_now() |> DateTime.to_unix()}.html"

            # Use blob download (works via localhost or HTTPS)
            {:noreply,
             push_event(socket, "download", %{
               filename: filename,
               content: html,
               mime_type: "text/html"
             })}
          rescue
            e ->
              Logger.error("[WireframeEditor] Failed to generate HTML: #{Exception.message(e)}")
              Logger.error(Exception.format(:error, e, __STACKTRACE__))
              {:noreply, socket}
          end
        else
          Logger.warning("[WireframeEditor] Could not load wireframe state for download")
          {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("resize_panel", %{"width" => width_str}, socket) do
    width = String.to_integer(width_str)
    # Clamp between 30% and 60%
    clamped_width = max(30, min(60, width))
    {:noreply, assign(socket, left_panel_width: clamped_width)}
  end

  @impl true
  def handle_info(:check_uploads, socket) do
    socket = process_completed_uploads(socket)

    # If there are still uploads in progress, schedule another check
    entries = socket.assigns.uploads.html_file.entries
    in_progress = Enum.filter(entries, &(!&1.done?))

    if length(in_progress) > 0 do
      Process.send_after(self(), :check_uploads, 500)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:clear_sent_feedback, component_id}, socket) do
    # Forward to nested UserInputComponent (inside ChatPanel)
    alias KoalemosWeb.UserInputComponent
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
      "[WireframeEditor] User input submitted: text=#{text}, images=#{length(images)}"
    )

    # Send user input to routine
    data = %{text: text, images: images, include_screenshot: include_screenshot}
    Engine.send_external_event(socket.assigns.routine_id, :user_input, data)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_messages, new_messages}, socket) do
    Logger.debug("[WireframeEditor] Received #{length(new_messages)} new message(s)")

    # Append new messages to existing messages
    updated_messages = socket.assigns.messages ++ new_messages

    # Update lens_state from latest context if available
    socket = update_lens_state_from_messages(socket, new_messages)

    {:noreply, assign(socket, messages: updated_messages)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "routine_completed"} = event}, socket) do
    Logger.info("[WireframeEditor] Routine completed")

    error = get_in(event, [:metadata, :final_context, :error])
    status = if error, do: :error, else: :completed

    {:noreply,
     assign(socket,
       status: status,
       last_error: error,
       current_step: nil
     )}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "error_occurred"} = event}, socket) do
    error_msg = get_in(event, [:metadata, :reason]) || "Unknown error"
    Logger.error("[WireframeEditor] Routine error: #{error_msg}")

    {:noreply,
     assign(socket,
       status: :error,
       last_error: error_msg,
       current_step: nil
     )}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "step_started"} = event}, socket) do
    step = event.step_id
    routine_module = Map.get(event, :routine_module)
    execution_stack = Map.get(event, :execution_stack, [])
    step_module = get_in(event, [:metadata, :step_module])

    {:noreply,
     assign(socket,
       current_step: step,
       routine_module: routine_module,
       execution_stack: execution_stack,
       step_module: step_module
     )}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "step_completed"}}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:routine_event, %{event_type: "context_changed", context_diff: context_diff}},
        socket
      ) do
    Logger.info("[WireframeEditor] Received context_changed event")

    # Extract lens_state from context_diff if present
    socket =
      case extract_lens_state_from_diff(context_diff) do
        {:ok, lens_state} ->
          Logger.info("[WireframeEditor] Found lens_state in context_diff, updating")

          # Update cache with new lens_state
          if socket.assigns.routine_id do
            Koalemos.Caches.WireframeStateCache.put_state(socket.assigns.routine_id, lens_state)

            # Broadcast DOM tree update
            dom_tree = get_in(lens_state, [:designed, :dom_tree])

            if dom_tree do
              Phoenix.PubSub.broadcast(
                Koalemos.PubSub,
                "wireframe_updates:#{socket.assigns.routine_id}",
                {:dom_tree_updated, dom_tree, %{source: :agent_modification}}
              )
            end
          end

          assign(socket, lens_state: lens_state)

        :not_found ->
          socket
      end

    {:noreply, socket}
  end

  # Catch-all for other routine events
  @impl true
  def handle_info({:routine_event, _event}, socket) do
    {:noreply, socket}
  end

  # Ultimate catch-all
  @impl true
  def handle_info(message, socket) do
    Logger.debug("[WireframeEditor] Unhandled message: #{inspect(message)}")
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-50">
      <!-- Header -->
      <div class="bg-white border-b border-slate-200 shadow-sm">
        <div class="px-4 py-3 flex items-center justify-between">
          <div class="flex items-center gap-4">
            <h1 class="text-xl font-semibold text-slate-800">Wireframe Editor</h1>
            <%= if @current_sample do %>
              <div class="text-sm text-slate-600">
                <span class="font-medium">{@current_sample}</span>
              </div>
            <% end %>
          </div>
          <div class="flex items-center gap-3">
            <%= if @routine_id && @lens_state do %>
              <button
                phx-click="save_wireframe"
                class="px-3 py-1.5 text-sm font-medium text-blue-600 hover:text-blue-700 hover:bg-blue-50 rounded-lg transition-colors flex items-center gap-1.5"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
                  />
                </svg>
                Save Page
              </button>
            <% end %>
            <button
              phx-click="new_wireframe"
              class="px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-100 rounded-lg transition-colors"
            >
              New Wireframe
            </button>
            <a
              href="/"
              class="text-sm text-blue-600 hover:text-blue-800 font-medium transition-colors"
            >
              ← Home
            </a>
          </div>
        </div>
      </div>
      <!-- Sample Selection Modal -->
      <%= if @show_sample_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white rounded-2xl shadow-2xl max-w-2xl w-full mx-4 p-6">
            <h2 class="text-2xl font-bold text-slate-800 mb-2">Choose a Wireframe to Edit</h2>
            <p class="text-sm text-slate-600 mb-6">
              Select a sample wireframe or upload your own HTML file to get started
            </p>
            <!-- Sample Selection -->
            <div class="space-y-3 mb-6">
              <%= for {id, name, _filename, description} <- @available_samples do %>
                <button
                  phx-click="select_sample"
                  phx-value-sample={id}
                  class="w-full px-4 py-4 rounded-xl border-2 border-slate-200 bg-white text-left hover:border-blue-400 hover:bg-blue-50 transition-all group"
                >
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <div class="font-semibold text-slate-800 group-hover:text-blue-700 mb-1">
                        {name}
                      </div>
                      <div class="text-sm text-slate-600">{description}</div>
                    </div>
                    <svg
                      class="w-5 h-5 text-slate-400 group-hover:text-blue-500 mt-1"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M9 5l7 7-7 7"
                      />
                    </svg>
                  </div>
                </button>
              <% end %>
            </div>
            <!-- File Upload -->
            <div class="border-t border-slate-200 pt-6">
              <h3 class="text-sm font-semibold text-slate-700 mb-3">Or upload your own HTML</h3>
              <form phx-change="validate">
                <div class="border-2 border-dashed border-slate-300 rounded-xl p-6 hover:border-blue-400 transition-colors bg-slate-50">
                  <.live_file_input
                    upload={@uploads.html_file}
                    class="block w-full text-sm text-slate-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-blue-600 file:text-white hover:file:bg-blue-700 cursor-pointer"
                  />
                  <p class="text-xs text-slate-500 mt-2">
                    HTML or HTM files only (max 1MB)
                  </p>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
      <!-- Main Content: Chat + Preview -->
      <%= if @agent_running && @routine_id && @lens_state do %>
        <div class="flex-1 overflow-hidden flex" id="resizable-container">
          <!-- Left Panel: Chat -->
          <div
            class="border-r border-slate-300 bg-white flex flex-col"
            style={"width: #{@left_panel_width}%"}
          >
            <.live_component
              module={ChatPanel}
              id="wireframe-chat-panel"
              routine_id={@routine_id}
              messages={@messages}
              mock_responses={false}
              current_step={@current_step}
              routine_module={@routine_module}
              execution_stack={@execution_stack}
              step_module={@step_module}
              disabled={@status in [:completed, :error] || @last_error != nil}
              status={@status}
              last_error={@last_error}
              tool_display={@tool_display}
              show_system_messages={@show_system_messages}
            />
          </div>
          <!-- Resize Handle -->
          <div
            class="w-1 bg-slate-300 hover:bg-blue-500 cursor-col-resize transition-colors"
            phx-hook="PanelResizer"
            id="resize-handle"
          >
          </div>
          <!-- Right Panel: Preview -->
          <div class="flex-1 bg-white flex flex-col overflow-hidden">
            <div class="border-b border-slate-200 px-4 py-2 bg-slate-50">
              <div class="flex items-center justify-between">
                <span class="text-sm font-medium text-slate-700">Live Preview</span>
                <span class="text-xs text-slate-500">Updates in real-time as you chat</span>
              </div>
            </div>
            <div class="flex-1 overflow-hidden">
              <iframe
                src={"/wireframe-preview/#{@routine_id}"}
                class="w-full h-full border-0"
                id="wireframe-preview"
                sandbox="allow-scripts allow-same-origin allow-forms"
                title="Wireframe Preview"
              >
              </iframe>
            </div>
          </div>
        </div>
      <% end %>
      <!-- Error Display -->
      <%= if @last_error do %>
        <div class="absolute bottom-4 left-4 right-4 max-w-2xl mx-auto">
          <div class="bg-red-50 border border-red-200 rounded-lg p-3 shadow-lg">
            <div class="flex items-start">
              <div class="text-red-600 mr-2">⚠</div>
              <div class="text-sm text-red-800">
                {@last_error}
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Private functions

  defp process_completed_uploads(socket) do
    # Check if there are any completed entries to process
    entries = socket.assigns.uploads.html_file.entries
    completed_entries = Enum.filter(entries, & &1.done?)
    in_progress_entries = Enum.filter(entries, &(!&1.done?))

    # Only process if ALL entries are done (no entries in progress)
    if length(completed_entries) > 0 and length(in_progress_entries) == 0 do
      Logger.info("[WireframeEditor] Processing #{length(completed_entries)} completed uploads")

      try do
        # Process the uploaded files
        uploaded_files =
          consume_uploaded_entries(socket, :html_file, fn %{path: path}, entry ->
            case File.read(path) do
              {:ok, content} ->
                {:ok, {content, entry.client_name}}

              {:error, reason} ->
                Logger.error(
                  "[WireframeEditor] Failed to read uploaded file: #{inspect(reason)}"
                )

                {:postpone, :error}
            end
          end)

        # Take the first uploaded file (we only allow 1)
        case uploaded_files do
          [{html_content, filename} | _] ->
            # Generate unique routine_id
            routine_id = "wireframe-editor-#{:erlang.unique_integer([:positive])}"

            # Auto-load the file
            {lens_state, _agent_context} = parse_and_create_lens_state(html_content)

            # Store lens_state in cache for preview to fetch on mount
            if lens_state do
              Koalemos.Caches.WireframeStateCache.put_state(routine_id, lens_state)

              # Also broadcast for any already-mounted previews
              dom_tree = get_in(lens_state, [:designed, :dom_tree])

              Phoenix.PubSub.broadcast(
                Koalemos.PubSub,
                "wireframe_updates:#{routine_id}",
                {:dom_tree_updated, dom_tree, %{source: :file_upload}}
              )
            end

            # Subscribe to routine events
            if connected?(socket) do
              Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
              Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")
            end

            # Auto-start WireframeDesignRoutine with uploaded file
            user_context = %{
              routine_id: routine_id,
              llm_provider: "anthropic",
              llm_model: "claude-sonnet-4-5",
              max_tokens: 64000,
              temperature: 0.7,
              wireframe_html: html_content
            }

            case EngineManager.start_routine(routine_id, WireframeDesignRoutine, user_context) do
              {:ok, _pid} ->
                Logger.info("[WireframeEditor] Started routine #{routine_id} with uploaded file")

                assign(socket,
                  routine_id: routine_id,
                  loaded_html: html_content,
                  current_sample: filename,
                  lens_state: lens_state,
                  show_sample_modal: false,
                  agent_running: true,
                  status: :running,
                  messages: [],
                  last_error: nil
                )

              {:error, reason} ->
                Logger.error("[WireframeEditor] Failed to start routine: #{inspect(reason)}")

                assign(socket,
                  last_error: "Failed to start routine: #{inspect(reason)}"
                )
            end

          [] ->
            Logger.warning("[WireframeEditor] No files were successfully processed")
            socket
        end
      rescue
        e ->
          Logger.error("[WireframeEditor] Error processing uploads: #{inspect(e)}")
          assign(socket, last_error: "Failed to process uploaded file")
      end
    else
      socket
    end
  end

  defp parse_and_create_lens_state(html_content) do
    # Generate unique routine ID for cache storage
    routine_id = "wireframe-editor-parse-#{:erlang.unique_integer([:positive])}"

    case ParsingIntegration.parse_wireframe(html_content, routine_id) do
      {:ok, wireframe} ->
        # Create lens state
        lens_state = %{
          designed: %{
            dom_tree: wireframe.dom_tree,
            style_elements: wireframe.styles,
            script_elements: wireframe.scripts,
            custom_css: extract_css_rules_as_map(wireframe.css_rules),
            custom_functions: Map.get(wireframe.javascript, :functions, %{}),
            custom_variables: Map.get(wireframe.javascript, :variables, %{}),
            init_scripts: extract_init_scripts_as_map(wireframe.javascript.init_scripts),
            handlers: Map.get(wireframe.javascript, :handlers, %{}),
            metadata: wireframe.metadata
          },
          running: %{},
          modifications: []
        }

        # Generate agent context
        state = %{context: %{lens_state: lens_state}}
        context_blocks = WireframeEditor.provide_context(state)

        # Extract text from context blocks
        agent_context =
          case context_blocks do
            [%{type: "text", text: text}] -> text
            [%{type: "text", text: text}, _image_block] -> text
            _ -> "No context generated"
          end

        {lens_state, agent_context}

      {:error, _reason} ->
        {nil, "Failed to parse HTML"}
    end
  end

  # Convert CSS rules list to map format (selector -> declarations)
  defp extract_css_rules_as_map(css_rules) when is_list(css_rules) do
    Enum.reduce(css_rules, %{}, fn rule, acc ->
      Map.put(acc, rule.selector, rule.declarations)
    end)
  end

  defp extract_css_rules_as_map(_), do: %{}

  # Convert init scripts list to map with index keys
  defp extract_init_scripts_as_map(init_scripts) when is_list(init_scripts) do
    init_scripts
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {script, idx}, acc ->
      if script != "" do
        Map.put(acc, "init_#{idx}", script)
      else
        acc
      end
    end)
  end

  defp extract_init_scripts_as_map(_), do: %{}

  defp update_lens_state_from_messages(socket, new_messages) do
    # Extract lens_state from tool results in messages and update cache
    Enum.reduce(new_messages, socket, fn msg, acc_socket ->
      case msg do
        %{role: "assistant", lens_state: lens_state} when not is_nil(lens_state) ->
          Logger.info("[WireframeEditor] Found lens_state in assistant message, updating")

          # Update cache with new lens_state
          if socket.assigns.routine_id do
            Koalemos.Caches.WireframeStateCache.put_state(socket.assigns.routine_id, lens_state)

            # Broadcast DOM tree update
            dom_tree = get_in(lens_state, [:designed, :dom_tree])

            if dom_tree do
              Logger.info("[WireframeEditor] Broadcasting DOM update from message")

              Phoenix.PubSub.broadcast(
                Koalemos.PubSub,
                "wireframe_updates:#{socket.assigns.routine_id}",
                {:dom_tree_updated, dom_tree, %{source: :agent_modification}}
              )
            end
          end

          assign(acc_socket, lens_state: lens_state)

        _ ->
          acc_socket
      end
    end)
  end

  # Extract lens_state from context_diff
  defp extract_lens_state_from_diff(diff) when is_list(diff) do
    Logger.debug("[WireframeEditor] Extracting lens_state from #{length(diff)} diff operations")

    result =
      Enum.reduce_while(diff, :not_found, fn operation, _acc ->
        case operation do
          # Handle both serialized (string) and non-serialized (atom) formats
          ["add_or_update", updates] when is_map(updates) ->
            case Map.get(updates, :lens_state) || Map.get(updates, "lens_state") do
              nil -> {:cont, :not_found}
              lens_state -> {:halt, {:ok, lens_state}}
            end

          [:add_or_update, updates] when is_map(updates) ->
            case Map.get(updates, :lens_state) || Map.get(updates, "lens_state") do
              nil -> {:cont, :not_found}
              lens_state -> {:halt, {:ok, lens_state}}
            end

          {:add_or_update, updates} when is_map(updates) ->
            case Map.get(updates, :lens_state) || Map.get(updates, "lens_state") do
              nil -> {:cont, :not_found}
              lens_state -> {:halt, {:ok, lens_state}}
            end

          _ ->
            {:cont, :not_found}
        end
      end)

    case result do
      {:ok, _} -> result
      :not_found -> :not_found
    end
  end

  defp extract_lens_state_from_diff(_), do: :not_found

  defp load_sample_html(sample_id) do
    case Enum.find(@available_samples, fn {id, _name, _file, _desc} -> id == sample_id end) do
      {_id, _name, filename, _desc} ->
        path = Path.join([:code.priv_dir(:koalemos), "wireframes", filename])

        case File.read(path) do
          {:ok, content} -> {:ok, content}
          {:error, reason} -> {:error, "File read error: #{inspect(reason)}"}
        end

      nil ->
        {:error, "Unknown sample: #{sample_id}"}
    end
  end

  defp get_sample_name(sample_id) do
    case Enum.find(@available_samples, fn {id, _name, _file, _desc} -> id == sample_id end) do
      {_id, name, _file, _desc} -> name
      nil -> "Unknown"
    end
  end

  # Generate complete HTML file from designed wireframe state
  defp generate_wireframe_html(wireframe_state) when is_map(wireframe_state) do
    designed = Map.get(wireframe_state, :designed, %{})
    dom_tree = Map.get(designed, :dom_tree)
    custom_css = Map.get(designed, :custom_css, %{})
    custom_variables = Map.get(designed, :custom_variables, %{})
    custom_functions = Map.get(designed, :custom_functions, %{})
    init_scripts = Map.get(designed, :init_scripts, %{})
    handlers = Map.get(designed, :handlers, %{})

    # Use the same rendering helpers as WireframePreviewLive
    alias KoalemosWeb.WireframePreviewLive, as: Preview

    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Wireframe Export</title>

        <style>
          /* Reset and base styles */
          * { box-sizing: border-box; }
          body { margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; }
        </style>
        #{if map_size(custom_css) > 0 do
      """
        <style>
          /* Custom CSS */
          #{Preview.render_custom_css(custom_css)}
        </style>
      """
    else
      ""
    end}
      </head>
      <body>
        #{Phoenix.HTML.safe_to_string(Preview.render_dom_tree(dom_tree))}

        #{if has_javascript?(custom_variables, custom_functions, init_scripts, handlers) do
      """
        <script>
          // Global Variables
          #{Preview.render_custom_variables(custom_variables)}

          // Function Definitions
          #{Preview.render_custom_functions(custom_functions)}

          // Event Handlers (attached on load)
          window.addEventListener('DOMContentLoaded', function() {
            #{render_handlers(handlers)}
          });

          // Initialization Scripts
          #{Preview.render_init_scripts(init_scripts)}
        </script>
      """
    else
      ""
    end}
      </body>
    </html>
    """
  end

  defp generate_wireframe_html(_invalid_state),
    do: "<html><body>Invalid wireframe state</body></html>"

  defp has_javascript?(variables, functions, init_scripts, handlers) do
    map_size(variables) > 0 or map_size(functions) > 0 or
      map_size(init_scripts) > 0 or map_size(handlers) > 0
  end

  defp render_handlers(handlers) when is_map(handlers) and map_size(handlers) > 0 do
    handlers
    |> Enum.flat_map(fn {element_id, event_handlers} ->
      Enum.map(event_handlers, fn {event_type, handler_config} ->
        event_name = to_string(event_type)

        handler_body =
          case handler_config do
            %{body: body} -> body
            %{"body" => body} -> body
            code when is_binary(code) -> code
            _ -> ""
          end

        """
        var el = document.getElementById('#{element_id}');
        if (el) {
          el.addEventListener('#{event_name}', function(e) {
            #{handler_body}
          });
        }
        """
      end)
    end)
    |> Enum.join("\n")
  end

  defp render_handlers(_), do: ""
end
