defmodule KoalemosWeb.WireframeTestLive do
  @moduledoc """
  Interactive wireframe test page (M4 Sprints 1 & 4).

  Provides a complete manual testing environment for the wireframe editor system:
  - Load and preview sample HTML files (simple, medium, complex)
  - File upload for custom HTML testing
  - **Live preview** via WireframePreviewLive in iframe (LiveView-in-iframe architecture)
  - Parse HTML using ParsingIntegration (HTMLParser + JavaScriptParser)
  - Display agent context (what WireframeEditor lens provides to agent)
  - Visualize lens_state structure (designed version of DOM tree)

  ## Sprint 4 Updates (Nov 5, 2025)

  Changed from static srcdoc to dynamic LiveView preview:
  - Generates unique routine_id for each wireframe load
  - Stores lens_state in WireframeStateCache for preview to fetch on mount
  - Broadcasts DOM tree updates via PubSub (enables live updates)
  - Preview iframe loads from /wireframe-preview/:routine_id route
  - Shows parsed DOM tree structure in "Agent Context" tab

  ## Architecture

  Test page → Parse HTML → Store in cache → Render iframe with routine_id →
  WireframePreviewLive mounts → Fetches from cache → Subscribes to PubSub →
  Renders DOM tree → Ready for live updates

  Route: /test/wireframe
  """
  use KoalemosWeb, :live_view
  require Logger

  alias Koalemos.Integrations.ParsingIntegration
  alias Koalemos.Lenses.WireframeEditor
  alias Koalemos.{EngineManager, Engine}
  alias Koalemos.Routines.WireframeTestRoutine
  alias KoalemosWeb.ChatPanel

  @fixtures_path "test/fixtures"
  @available_samples [
    {"simple", "Simple Wireframe", "wireframe_simple.html"},
    {"medium", "Medium Wireframe", "wireframe_medium.html"},
    {"complex", "Complex Wireframe", "wireframe_complex.html"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Wireframe Test",
       current_html: nil,
       current_sample: nil,
       available_samples: @available_samples,
       loaded_html: nil,
       error_message: nil,
       lens_state: nil,
       agent_context: nil,
       show_context: false,
       routine_id: nil,
       # Chat/agent fields
       messages: [],
       status: :idle,
       current_step: nil,
       last_error: nil,
       agent_running: false,
       # Tab selection
       active_tab: "preview"
     )
     |> allow_upload(:html_file,
       accept: ~w(.html .htm),
       max_entries: 1,
       max_file_size: 1_000_000,
       auto_upload: true
     )}
  end

  @impl true
  def handle_event("load_sample", %{"sample" => sample_id}, socket) do
    Logger.info("[WireframeTestLive] Loading sample: #{sample_id}")

    case load_sample_html(sample_id) do
      {:ok, html_content} ->
        sample_name = get_sample_name(sample_id)

        Logger.info(
          "[WireframeTestLive] Successfully loaded #{sample_id}: #{byte_size(html_content)} bytes"
        )

        # Generate unique routine_id for this wireframe session
        routine_id = "wireframe-test-#{:erlang.unique_integer([:positive])}"

        # Parse HTML and create lens state
        {lens_state, agent_context} = parse_and_create_lens_state(html_content)

        # Store lens_state in cache for preview to fetch on mount
        if lens_state do
          Koalemos.Caches.WireframeStateCache.put_state(routine_id, lens_state)

          # Also broadcast for any already-mounted previews
          dom_tree = get_in(lens_state, [:designed, :dom_tree])
          Phoenix.PubSub.broadcast(
            Koalemos.PubSub,
            "wireframe_updates:#{routine_id}",
            {:dom_tree_updated, dom_tree, %{source: :initial_load}}
          )
        end

        {:noreply,
         assign(socket,
           routine_id: routine_id,
           loaded_html: html_content,
           current_sample: sample_id,
           current_html: sample_name,
           error_message: nil,
           lens_state: lens_state,
           agent_context: agent_context
         )}

      {:error, reason} ->
        Logger.error("[WireframeTestLive] Failed to load sample #{sample_id}: #{inspect(reason)}")

        {:noreply,
         assign(socket,
           error_message: "Failed to load sample: #{reason}",
           loaded_html: nil,
           lens_state: nil,
           agent_context: nil,
           routine_id: nil
         )}
    end
  end

  @impl true
  def handle_event("clear_wireframe", _params, socket) do
    Logger.info("[WireframeTestLive] Clearing wireframe")

    {:noreply,
     assign(socket,
       loaded_html: nil,
       current_sample: nil,
       current_html: nil,
       error_message: nil,
       lens_state: nil,
       agent_context: nil,
       routine_id: nil
     )}
  end

  @impl true
  def handle_event("toggle_context", _params, socket) do
    new_show_context = !socket.assigns.show_context
    Logger.info("[WireframeTestLive] Toggling context drawer from #{socket.assigns.show_context} to #{new_show_context}")

    # When OPENING the drawer, regenerate context with current live state
    socket = if new_show_context && socket.assigns.lens_state do
      Logger.info("[WireframeTestLive] Regenerating agent_context with live state capture")
      agent_context = regenerate_agent_context(socket.assigns.lens_state, socket.assigns.routine_id)
      assign(socket, agent_context: agent_context)
    else
      socket
    end

    {:noreply, assign(socket, show_context: new_show_context)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
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
  def handle_event("start_agent", _params, socket) do
    Logger.info("[WireframeTestLive] Starting agent for routine #{socket.assigns.routine_id}")

    routine_id = socket.assigns.routine_id
    loaded_html = socket.assigns.loaded_html

    if routine_id && loaded_html && !socket.assigns.agent_running do
      # Subscribe to routine events
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")
      end

      # Start the WireframeTestRoutine with the loaded wireframe HTML
      # The routine's setup/2 will parse it and create lens_state
      user_context = %{
        routine_id: routine_id,
        llm_provider: "anthropic",
        llm_model: "claude-haiku-4-5",
        max_tokens: 64000,
        temperature: 0.7,
        wireframe_html: loaded_html
      }

      case EngineManager.start_routine(routine_id, WireframeTestRoutine, user_context) do
        {:ok, _pid} ->
          Logger.info("[WireframeTestLive] Started agent successfully")

          {:noreply,
           assign(socket,
             agent_running: true,
             status: :running,
             messages: [],
             last_error: nil
           )}

        {:error, reason} ->
          Logger.error("[WireframeTestLive] Failed to start agent: #{inspect(reason)}")

          {:noreply,
           assign(socket,
             last_error: "Failed to start agent: #{inspect(reason)}"
           )}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("stop_agent", _params, socket) do
    Logger.info("[WireframeTestLive] Stopping agent")

    {:noreply,
     assign(socket,
       agent_running: false,
       status: :idle,
       messages: []
     )}
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
  def handle_info({:screenshot_request, %{routine_id: _requested_id}}, socket) do
    # Wireframe editor doesn't support screenshots yet
    # Just ignore the request
    {:noreply, socket}
  end

  @impl true
  def handle_info({:mock_ai_response, _message}, socket) do
    # Mock responses not used in this live view (mock_responses: false)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_input_submitted, %{text: text, images: images, include_screenshot: include_screenshot}}, socket) do
    Logger.info("[WireframeTestLive] User input submitted: text=#{text}, images=#{length(images)}")

    # Send user input to routine
    data = %{text: text, images: images, include_screenshot: include_screenshot}
    Engine.send_external_event(socket.assigns.routine_id, :user_input, data)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_messages, new_messages}, socket) do
    Logger.debug("[WireframeTestLive] Received #{length(new_messages)} new message(s)")

    # Append new messages to existing messages
    updated_messages = socket.assigns.messages ++ new_messages

    # Update lens_state from latest context if available
    socket = update_lens_state_from_messages(socket, new_messages)

    {:noreply, assign(socket, messages: updated_messages)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "routine_completed"} = event}, socket) do
    Logger.info("[WireframeTestLive] Routine completed")

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
    Logger.error("[WireframeTestLive] Routine error: #{error_msg}")

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

    {:noreply, assign(socket, current_step: step)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "step_completed"}}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "context_changed", context_diff: context_diff}}, socket) do
    Logger.info("[WireframeTestLive] Received context_changed event")

    # Log structure without huge data
    diff_summary = Enum.map(context_diff, fn
      {op, data} when is_map(data) -> {op, Map.keys(data)}
      [op, data] when is_map(data) -> [op, Map.keys(data)]
      other -> other
    end)
    Logger.debug("[WireframeTestLive] context_diff operations: #{inspect(diff_summary)}")

    # Extract lens_state from context_diff if present
    socket = case extract_lens_state_from_diff(context_diff) do
      {:ok, lens_state} ->
        Logger.info("[WireframeTestLive] ✓ Found lens_state in context_diff, updating cache and agent_context")

        # Check if DOM tree has classes to verify
        dom_tree = get_in(lens_state, [:designed, :dom_tree])
        Logger.debug("[WireframeTestLive] DOM tree present: #{not is_nil(dom_tree)}")

        # Update cache
        if socket.assigns.routine_id do
          Koalemos.Caches.WireframeStateCache.put_state(socket.assigns.routine_id, lens_state)
          Logger.info("[WireframeTestLive] Updated cache for routine #{socket.assigns.routine_id}")
        end

        # Regenerate agent context with live state capture
        agent_context = regenerate_agent_context(lens_state, socket.assigns.routine_id)
        Logger.info("[WireframeTestLive] Regenerated agent_context (#{String.length(agent_context)} chars)")

        assign(socket, lens_state: lens_state, agent_context: agent_context)

      :not_found ->
        Logger.warning("[WireframeTestLive] ✗ No lens_state found in context_diff")
        socket
    end

    {:noreply, socket}
  end

  # Catch-all for other routine events (routine_started, transition_taken, step_setup, etc.)
  @impl true
  def handle_info({:routine_event, _event}, socket) do
    {:noreply, socket}
  end

  # Ultimate catch-all for any other unhandled messages
  @impl true
  def handle_info(message, socket) do
    Logger.debug("[WireframeTestLive] Unhandled message: #{inspect(message)}")
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-100">
      <!-- Header -->
      <div class="bg-white border-b border-slate-200 shadow-sm">
        <div class="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
          <div>
            <h1 class="text-xl font-semibold text-slate-800">Wireframe Test Environment</h1>
            <p class="text-sm text-slate-600 mt-1">
              M4 Sprint 1: Test infrastructure for WireframeEditor lens
            </p>
          </div>
          <div class="flex items-center gap-4">
            <%= if @current_html do %>
              <div class="text-sm text-green-600">
                <span class="font-medium">Loaded:</span>
                <span class="font-mono"><%= @current_html %></span>
              </div>
            <% end %>
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
            <strong>Sprint 4 Test:</strong>
            Select a sample to see (1) the HTML preview, and (2) what context the WireframeEditor lens provides to the agent. This verifies the "Context = Information" philosophy.
          </p>
        </div>
      </div>
      <!-- Main Content: Control Panel/Chat + Preview -->
      <div class="flex-1 overflow-hidden flex">
        <!-- Left Panel: Control Panel OR Chat Panel -->
        <%= if @agent_running do %>
          <!-- Chat Panel (when agent running) -->
          <div class="w-1/3 border-r border-slate-300 bg-white flex flex-col">
            <.live_component
              module={ChatPanel}
              id="wireframe-chat-panel"
              routine_id={@routine_id}
              messages={@messages}
              mock_responses={false}
              current_step={@current_step}
              disabled={@status in [:completed, :error] || @last_error != nil}
              status={@status}
              last_error={@last_error}
            />
          </div>
        <% else %>
          <!-- Control Panel (when agent not running) -->
          <div class="w-1/3 border-r border-slate-300 bg-white flex flex-col p-4 overflow-auto">
          <div class="space-y-6">
            <!-- File Upload -->
            <div>
              <h2 class="text-lg font-semibold text-slate-800 mb-3">Load HTML File</h2>
              <form phx-change="validate" class="space-y-2">
                <div class="border-2 border-dashed border-slate-300 rounded-lg p-4 hover:border-blue-400 transition-colors">
                  <.live_file_input upload={@uploads.html_file} class="block w-full text-sm text-slate-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100 cursor-pointer" />
                  <p class="text-xs text-slate-500 mt-2">HTML or HTM files only (max 1MB)</p>
                </div>
              </form>
            </div>

            <!-- Sample Selection -->
            <div>
              <h2 class="text-lg font-semibold text-slate-800 mb-3">Or Choose Sample</h2>
              <div class="space-y-2">
                <%= for {id, name, _filename} <- @available_samples do %>
                  <button
                    phx-click="load_sample"
                    phx-value-sample={id}
                    class={[
                      "w-full px-4 py-3 rounded-lg border-2 transition-all text-left",
                      if(@current_sample == id,
                        do: "border-blue-500 bg-blue-50 text-blue-900",
                        else: "border-slate-200 bg-white text-slate-700 hover:border-blue-300 hover:bg-blue-50"
                      )
                    ]}
                  >
                    <div class="font-medium"><%= name %></div>
                    <div class="text-xs text-slate-500 mt-1">
                      Click to load and preview
                    </div>
                  </button>
                <% end %>
              </div>
            </div>
            <!-- Actions -->
            <div>
              <h2 class="text-lg font-semibold text-slate-800 mb-3">Actions</h2>
              <div class="space-y-2">
                <%= if @agent_running do %>
                  <button
                    phx-click="stop_agent"
                    class="w-full px-4 py-2 rounded-lg font-medium transition-colors bg-red-600 text-white hover:bg-red-700"
                  >
                    Stop Agent
                  </button>
                <% else %>
                  <button
                    phx-click="start_agent"
                    disabled={is_nil(@loaded_html)}
                    class={[
                      "w-full px-4 py-2 rounded-lg font-medium transition-colors",
                      if(is_nil(@loaded_html),
                        do: "bg-slate-100 text-slate-400 cursor-not-allowed",
                        else: "bg-green-600 text-white hover:bg-green-700"
                      )
                    ]}
                  >
                    Start Agent
                  </button>
                <% end %>
                <button
                  phx-click="clear_wireframe"
                  disabled={is_nil(@loaded_html)}
                  class={[
                    "w-full px-4 py-2 rounded-lg font-medium transition-colors",
                    if(is_nil(@loaded_html),
                      do: "bg-slate-100 text-slate-400 cursor-not-allowed",
                      else: "bg-red-600 text-white hover:bg-red-700"
                    )
                  ]}
                >
                  Clear Preview
                </button>
              </div>
            </div>
            <!-- Status -->
            <div>
              <h2 class="text-lg font-semibold text-slate-800 mb-3">Status</h2>
              <div class="bg-slate-50 border border-slate-200 rounded-lg p-3 space-y-2 text-sm">
                <div class="flex justify-between">
                  <span class="text-slate-600">Current Sample:</span>
                  <span class="font-mono text-slate-800">
                    <%= @current_sample || "None" %>
                  </span>
                </div>
                <%= if @loaded_html do %>
                  <div class="flex justify-between">
                    <span class="text-slate-600">HTML Size:</span>
                    <span class="font-mono text-slate-800">
                      <%= format_bytes(byte_size(@loaded_html)) %>
                    </span>
                  </div>
                <% end %>
                <div class="flex justify-between">
                  <span class="text-slate-600">Agent Status:</span>
                  <span class={[
                    "font-mono text-sm font-medium",
                    if(@agent_running, do: "text-green-600", else: "text-slate-600")
                  ]}>
                    <%= if @agent_running, do: "🟢 Running", else: "⚪ Idle" %>
                  </span>
                </div>
                <%= if @routine_id do %>
                  <div class="flex justify-between">
                    <span class="text-slate-600">Routine ID:</span>
                    <span class="font-mono text-xs text-slate-800">
                      <%= String.slice(@routine_id, 0..20) %>...
                    </span>
                  </div>
                <% end %>
              </div>
            </div>
            <!-- Error Display -->
            <%= if @error_message || @last_error do %>
              <div class="bg-red-50 border border-red-200 rounded-lg p-3">
                <div class="flex items-start">
                  <div class="text-red-600 mr-2">⚠</div>
                  <div class="text-sm text-red-800">
                    <%= @error_message || @last_error %>
                  </div>
                </div>
              </div>
            <% end %>
            <!-- Sprint Progress -->
            <div class="border-t border-slate-200 pt-4">
              <h2 class="text-sm font-semibold text-green-600 mb-2">✓ Sprint 4 Complete:</h2>
              <ul class="text-xs text-slate-600 space-y-1 list-disc list-inside">
                <li>WireframeEditor lens integration</li>
                <li>HTML parsing & DOM tree visualization</li>
                <li>Agent context rendering</li>
                <li>9 control tools registered</li>
              </ul>
              <h2 class="text-sm font-semibold text-slate-500 mb-2 mt-3">Coming in Future Sprints:</h2>
              <ul class="text-xs text-slate-500 space-y-1 list-disc list-inside">
                <li>Interactive tool execution UI</li>
                <li>Real-time DOM modification testing</li>
                <li>JavaScript & CSS editors</li>
                <li>Live agent sessions</li>
              </ul>
            </div>
          </div>
        </div>
        <% end %>

        <!-- Preview Panel (right side) - always full height -->
        <div class="w-2/3 bg-slate-50 flex flex-col relative">
          <!-- Preview Section -->
          <div class="flex-1 flex flex-col border-b border-slate-300">
            <div class="bg-slate-700 px-4 py-2 border-b border-slate-600 flex items-center justify-between">
              <h2 class="text-sm font-medium text-white">HTML Preview (Iframe)</h2>
              <div class="flex items-center gap-4">
                <%= if @agent_running do %>
                  <button
                    phx-click="stop_agent"
                    class="px-3 py-1 rounded-lg font-medium text-sm transition-colors bg-red-600 text-white hover:bg-red-700"
                  >
                    Stop Agent
                  </button>
                <% end %>
                <%= if @loaded_html do %>
                  <div class="text-xs text-slate-300">
                    Rendering in isolated iframe
                  </div>
                <% end %>
              </div>
            </div>
            <div class="flex-1 overflow-auto relative">
              <!-- Show Agent Context button (always rendered, hidden with CSS) -->
              <button
                phx-click="toggle_context"
                class={"absolute top-4 right-4 z-10 bg-green-600 hover:bg-green-700 text-white px-3 py-2 rounded-lg shadow-lg transition-all flex items-center gap-2 text-sm #{if @agent_running && @agent_context && !@show_context, do: "", else: "hidden"}"}
              >
                <span>🤖</span>
                <span class="font-medium">Agent Context</span>
                <span class="text-xs">▲</span>
              </button>

              <!-- Iframe - stable because parent has no structural changes -->
              <%= if @routine_id do %>
                <iframe
                  id="wireframe-preview"
                  src={"/wireframe-preview/#{@routine_id}"}
                  class="w-full h-full border-0"
                  sandbox="allow-scripts allow-same-origin allow-forms"
                  title="Wireframe Preview"
                >
                </iframe>
              <% else %>
                <div class="w-full h-full"></div>
              <% end %>

              <!-- Empty State (shown when no routine_id) -->
              <div class={"h-full flex items-center justify-center #{if @routine_id, do: "hidden", else: ""}"}>
                <div class="text-center text-slate-400">
                  <div class="text-6xl mb-4">📄</div>
                  <p class="text-lg font-medium mb-2">No wireframe loaded</p>
                  <p class="text-sm">
                    Select a sample HTML file from the left panel to preview it here
                  </p>
                </div>
              </div>
            </div>
          </div>

          <!-- Agent Context Drawer (slides up from bottom with bounce) -->
          <div class={"absolute bottom-0 left-0 right-0 #{if @show_context, do: "translate-y-0", else: "translate-y-full"}"} style="height: 60%; box-shadow: 0 -4px 20px rgba(0,0,0,0.3); transition: transform 0.6s cubic-bezier(0.68, -0.55, 0.265, 1.55);">
            <div class="h-full flex flex-col bg-slate-900">
              <div class="bg-green-700 px-4 py-3 border-b border-green-600 flex items-center justify-between cursor-pointer" phx-click="toggle_context">
                <h2 class="text-sm font-medium text-white">🤖 Agent Context (What the Agent Sees)</h2>
                <%= if @agent_context do %>
                  <button class="text-xs text-green-200 hover:text-white transition-colors px-3 py-1 bg-green-600 rounded">
                    <%= if @show_context, do: "▼ Hide", else: "▲ Show" %>
                  </button>
                <% end %>
              </div>
              <div class="flex-1 overflow-auto">
                <%= if @agent_context do %>
                  <pre class="text-xs text-green-300 p-4 font-mono leading-relaxed"><%= @agent_context %></pre>
                <% else %>
                  <div class="h-full flex items-center justify-center">
                    <div class="text-center text-slate-500">
                      <div class="text-4xl mb-3">🤖</div>
                      <p class="text-sm">Load a wireframe to see agent context</p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Toggle Button (when drawer is closed and agent not running) -->
          <%= if @agent_context && !@show_context && !@agent_running do %>
            <button
              phx-click="toggle_context"
              class="absolute bottom-4 right-4 bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg shadow-lg transition-all flex items-center gap-2"
            >
              <span class="text-lg">🤖</span>
              <span class="text-sm font-medium">Show Agent Context</span>
              <span class="text-xs">▲</span>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Private Helpers

  defp process_completed_uploads(socket) do
    # Check if there are any completed entries to process
    entries = socket.assigns.uploads.html_file.entries
    completed_entries = Enum.filter(entries, & &1.done?)
    in_progress_entries = Enum.filter(entries, &(!&1.done?))

    # Only process if ALL entries are done (no entries in progress)
    if length(completed_entries) > 0 and length(in_progress_entries) == 0 do
      Logger.info("[WireframeTestLive] Processing #{length(completed_entries)} completed uploads")

      try do
        # Process the uploaded files
        uploaded_files =
          consume_uploaded_entries(socket, :html_file, fn %{path: path}, entry ->
            case File.read(path) do
              {:ok, content} ->
                {:ok, {content, entry.client_name}}

              {:error, reason} ->
                Logger.error("[WireframeTestLive] Failed to read uploaded file: #{inspect(reason)}")
                {:postpone, :error}
            end
          end)

        # Take the first uploaded file (we only allow 1)
        case uploaded_files do
          [{html_content, filename} | _] ->
            # Generate unique routine_id
            routine_id = "wireframe-test-#{:erlang.unique_integer([:positive])}"

            # Auto-load the file
            {lens_state, agent_context} = parse_and_create_lens_state(html_content)

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

            assign(socket,
              routine_id: routine_id,
              loaded_html: html_content,
              current_sample: nil,
              current_html: filename,
              error_message: nil,
              lens_state: lens_state,
              agent_context: agent_context
            )

          [] ->
            Logger.warning("[WireframeTestLive] No files were successfully processed")
            socket
        end
      rescue
        e ->
          Logger.error("[WireframeTestLive] Error processing uploads: #{inspect(e)}")
          assign(socket, error_message: "Failed to process uploaded file")
      end
    else
      socket
    end
  end

  defp parse_and_create_lens_state(html_content) do
    # Generate unique routine ID for cache storage
    routine_id = "wireframe-test-live-#{:erlang.unique_integer([:positive])}"

    case ParsingIntegration.parse_wireframe(html_content, routine_id) do
      {:ok, wireframe} ->
        # Create lens state (using ParsingIntegration for full extraction)
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
        agent_context = case context_blocks do
          [%{type: "text", text: text}] -> text
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

  defp update_lens_state_from_messages(socket, new_messages) do
    # Extract lens_state from tool results in messages and update cache
    Enum.reduce(new_messages, socket, fn msg, acc_socket ->
      case msg do
        %{role: "assistant", lens_state: lens_state} when not is_nil(lens_state) ->
          Logger.info("[WireframeTestLive] Found lens_state in assistant message, updating")

          # Update cache with new lens_state
          if socket.assigns.routine_id do
            Koalemos.Caches.WireframeStateCache.put_state(socket.assigns.routine_id, lens_state)

            # Broadcast DOM tree update
            dom_tree = get_in(lens_state, [:designed, :dom_tree])
            if dom_tree do
              Logger.info("[WireframeTestLive] Broadcasting DOM update from message")
              Phoenix.PubSub.broadcast(
                Koalemos.PubSub,
                "wireframe_updates:#{socket.assigns.routine_id}",
                {:dom_tree_updated, dom_tree, %{source: :agent_modification}}
              )
            end
          end

          # Regenerate agent context from updated lens_state with live state capture
          agent_context = regenerate_agent_context(lens_state, socket.assigns.routine_id)

          assign(acc_socket, lens_state: lens_state, agent_context: agent_context)

        _ ->
          acc_socket
      end
    end)
  end

  # Regenerate agent context from lens_state
  defp regenerate_agent_context(lens_state, routine_id) do
    # Create a minimal state structure with lens_state and routine_id for WireframeEditor
    state = %{context: %{lens_state: lens_state, routine_id: routine_id}}

    # Call WireframeEditor.provide_context to regenerate the context
    context_blocks = WireframeEditor.provide_context(state)

    # Extract text from context blocks
    case context_blocks do
      [%{type: "text", text: text}] -> text
      _ -> "No context generated"
    end
  end

  # Extract lens_state from context_diff
  # Note: Observer.make_serializable converts tuples to lists and atoms to strings,
  # so {:add_or_update, ...} becomes ["add_or_update", ...] when broadcast via PubSub
  defp extract_lens_state_from_diff(diff) when is_list(diff) do
    Logger.debug("[WireframeTestLive] Extracting lens_state from #{length(diff)} diff operations")

    result = Enum.reduce_while(diff, :not_found, fn operation, _acc ->
      case operation do
        # Handle both serialized (string) and non-serialized (atom) formats
        ["add_or_update", updates] when is_map(updates) ->
          keys = Map.keys(updates)
          Logger.debug("[WireframeTestLive] Checking [\"add_or_update\", ...] with keys: #{inspect(keys)}")
          case Map.get(updates, :lens_state) || Map.get(updates, "lens_state") do
            nil ->
              Logger.debug("[WireframeTestLive] No lens_state key found")
              {:cont, :not_found}
            lens_state ->
              Logger.info("[WireframeTestLive] ✓ Found lens_state in [\"add_or_update\", ...]")
              {:halt, {:ok, lens_state}}
          end

        [:add_or_update, updates] when is_map(updates) ->
          keys = Map.keys(updates)
          Logger.debug("[WireframeTestLive] Checking [:add_or_update, ...] with keys: #{inspect(keys)}")
          case Map.get(updates, :lens_state) || Map.get(updates, "lens_state") do
            nil ->
              Logger.debug("[WireframeTestLive] No lens_state key found")
              {:cont, :not_found}
            lens_state ->
              Logger.info("[WireframeTestLive] ✓ Found lens_state in [:add_or_update, ...]")
              {:halt, {:ok, lens_state}}
          end

        {:add_or_update, updates} when is_map(updates) ->
          keys = Map.keys(updates)
          Logger.debug("[WireframeTestLive] Checking {:add_or_update, ...} with keys: #{inspect(keys)}")
          case Map.get(updates, :lens_state) || Map.get(updates, "lens_state") do
            nil ->
              Logger.debug("[WireframeTestLive] No :lens_state key found")
              {:cont, :not_found}
            lens_state ->
              Logger.info("[WireframeTestLive] ✓ Found :lens_state in {:add_or_update, ...}")
              {:halt, {:ok, lens_state}}
          end

        [op | _] ->
          Logger.debug("[WireframeTestLive] Skipping list operation: #{inspect(op)}")
          {:cont, :not_found}

        {op, _} ->
          Logger.debug("[WireframeTestLive] Skipping tuple operation: #{inspect(op)}")
          {:cont, :not_found}

        other ->
          Logger.debug("[WireframeTestLive] Skipping unknown operation: #{inspect(other)}")
          {:cont, :not_found}
      end
    end)

    case result do
      {:ok, _} -> result
      :not_found ->
        Logger.debug("[WireframeTestLive] ✗ lens_state not found in any operation")
        :not_found
    end
  end

  defp extract_lens_state_from_diff(_), do: :not_found

  defp load_sample_html(sample_id) do
    case Enum.find(@available_samples, fn {id, _name, _file} -> id == sample_id end) do
      {_id, _name, filename} ->
        path = Path.join([@fixtures_path, filename])

        case File.read(path) do
          {:ok, content} -> {:ok, content}
          {:error, reason} -> {:error, "File read error: #{inspect(reason)}"}
        end

      nil ->
        {:error, "Unknown sample: #{sample_id}"}
    end
  end

  defp get_sample_name(sample_id) do
    case Enum.find(@available_samples, fn {id, _name, _file} -> id == sample_id end) do
      {_id, name, _file} -> name
      nil -> "Unknown"
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
end
