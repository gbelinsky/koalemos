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
       routine_id: nil
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
    {:noreply, assign(socket, show_context: !socket.assigns.show_context)}
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
      <!-- Main Content: Control Panel + Preview -->
      <div class="flex-1 overflow-hidden flex">
        <!-- Control Panel (left side) -->
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
              </div>
            </div>
            <!-- Error Display -->
            <%= if @error_message do %>
              <div class="bg-red-50 border border-red-200 rounded-lg p-3">
                <div class="flex items-start">
                  <div class="text-red-600 mr-2">⚠</div>
                  <div class="text-sm text-red-800"><%= @error_message %></div>
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
        <!-- Preview Panel (right side) -->
        <div class="w-2/3 bg-slate-50 flex flex-col relative">
          <!-- Preview Section (full height) -->
          <div class="flex-1 flex flex-col">
            <div class="bg-slate-700 px-4 py-2 border-b border-slate-600 flex items-center justify-between">
              <h2 class="text-sm font-medium text-white">HTML Preview (Iframe)</h2>
              <%= if @loaded_html do %>
                <div class="text-xs text-slate-300">
                  Rendering in isolated iframe
                </div>
              <% end %>
            </div>
            <div class="flex-1 overflow-auto">
              <%= if @routine_id do %>
                <!-- Iframe Preview (LiveView) -->
                <iframe
                  id="wireframe-preview"
                  src={"/wireframe-preview/#{@routine_id}"}
                  class="w-full h-full border-0"
                  sandbox="allow-scripts allow-same-origin"
                  title="Wireframe Preview"
                >
                </iframe>
              <% else %>
                <!-- Empty State -->
                <div class="h-full flex items-center justify-center">
                  <div class="text-center text-slate-400">
                    <div class="text-6xl mb-4">📄</div>
                    <p class="text-lg font-medium mb-2">No wireframe loaded</p>
                    <p class="text-sm">
                      Select a sample HTML file from the left panel to preview it here
                    </p>
                  </div>
                </div>
              <% end %>
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

          <!-- Toggle Button (when drawer is closed) -->
          <%= if @agent_context && !@show_context do %>
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
