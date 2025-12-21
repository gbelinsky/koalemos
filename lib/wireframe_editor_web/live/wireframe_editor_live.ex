defmodule WireframeEditorWeb.WireframeEditorLive do
  @moduledoc """
  Consolidated wireframe editor LiveView with production and debug modes.

  Route: /wireframe-editor/:routine_id

  Query Parameters:
  - `mode=debug` - Show debug panels (default: production mode, no debug)
  - `routine=simple` - Use WireframeEditorRoutine (default: WireframeDesignRoutine)

  Features:
  - Config modal on first visit (skipped on page reload if routine exists)
  - Save/export wireframe as HTML
  - Debug panels (optional, controlled by mode)
  - Resizable panels
  """

  use WireframeEditorWeb, :live_view
  require Logger

  alias Koalemos.{EngineManager, Engine}
  alias WireframeEditorWeb.Routines.{WireframeEditorRoutine, WireframeDesignRoutine}
  alias WireframeEditorWeb.ChatPanel
  alias WireframeEditorWeb.WireframeConfigModal
  alias WireframeEditorWeb.Servers.WireframeStateServer

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Wireframe Editor",
       # Core state
       routine_id: nil,
       messages: [],
       status: :idle,
       current_step: nil,
       routine_module: nil,
       execution_stack: [],
       step_module: nil,
       last_error: nil,
       agent_running: false,
       # UI state
       left_panel_width: 40,
       tool_display: :inline,
       # Config modal state
       show_config_modal: false,
       current_sample: nil,
       provider: nil,
       model: nil,
       # Mode and routine type (from query params)
       mode: :production,
       routine_type: :design,
       # Debug panel state (only used in debug mode)
       designed_state: nil,
       running_state: nil,
       screenshot: nil,
       sync_status: nil
     ), layout: false}
  end

  @impl true
  def handle_params(%{"routine_id" => routine_id} = params, _uri, socket) do
    if connected?(socket) && socket.assigns.routine_id == nil do
      # Parse query params for mode and routine type
      mode = if params["mode"] == "debug", do: :debug, else: :production
      routine_type = if params["routine"] == "simple", do: :simple, else: :design

      # Subscribe to routine events
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")

      # Check if routine already exists (reconnection case)
      case EngineManager.get_routine(routine_id) do
        {:ok, _pid} ->
          Logger.info("[WireframeEditorLive] Reconnecting to existing routine #{routine_id}")
          Process.send_after(self(), :fetch_initial_state, 100)

          {:noreply,
           assign(socket,
             routine_id: routine_id,
             mode: mode,
             routine_type: routine_type,
             agent_running: true,
             status: :running,
             show_config_modal: false
           )}

        {:error, :not_found} ->
          # New routine - show config modal
          Logger.info("[WireframeEditorLive] New routine #{routine_id}, showing config modal")

          {:noreply,
           assign(socket,
             routine_id: routine_id,
             mode: mode,
             routine_type: routine_type,
             show_config_modal: true
           )}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # ============================================================================
  # Events
  # ============================================================================

  @impl true
  def handle_event("resize_panel", %{"width" => width_str}, socket) do
    width = String.to_integer(width_str)
    clamped_width = max(30, min(60, width))
    {:noreply, assign(socket, left_panel_width: clamped_width)}
  end

  @impl true
  def handle_event("new_wireframe", _params, socket) do
    # Stop current routine if running
    if socket.assigns.routine_id && socket.assigns.agent_running do
      EngineManager.stop_routine(socket.assigns.routine_id)
    end

    # Redirect to a new routine ID
    new_routine_id = "wireframe-#{:erlang.unique_integer([:positive])}"
    mode_param = if socket.assigns.mode == :debug, do: "?mode=debug", else: ""

    {:noreply, push_navigate(socket, to: "/wireframe-editor/#{new_routine_id}#{mode_param}")}
  end

  @impl true
  def handle_event("save_wireframe", _params, socket) do
    Logger.info("[WireframeEditorLive] Generating wireframe download")

    case socket.assigns[:routine_id] do
      nil ->
        {:noreply, socket}

      routine_id ->
        designed = WireframeStateServer.get_designed(routine_id)

        if designed do
          try do
            html = generate_wireframe_html(designed)
            Logger.info("[WireframeEditorLive] Generated HTML, length: #{String.length(html)} chars")
            filename = "wireframe_#{routine_id}_#{DateTime.utc_now() |> DateTime.to_unix()}.html"

            {:noreply,
             push_event(socket, "download", %{
               filename: filename,
               content: html,
               mime_type: "text/html"
             })}
          rescue
            e ->
              Logger.error("[WireframeEditorLive] Failed to generate HTML: #{Exception.message(e)}")
              {:noreply, socket}
          end
        else
          Logger.warning("[WireframeEditorLive] No designed state for download")
          {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("refresh_state", _params, socket) do
    routine_id = socket.assigns.routine_id
    Logger.info("[WireframeEditorLive] Manual state refresh requested")

    designed = WireframeStateServer.get_designed(routine_id)
    running = WireframeStateServer.get_running(routine_id)
    screenshot = WireframeStateServer.get_screenshot(routine_id)

    {:noreply,
     assign(socket,
       designed_state: designed,
       running_state: running,
       screenshot: screenshot,
       sync_status: "State refreshed"
     )}
  end

  # ============================================================================
  # Info Handlers
  # ============================================================================

  @impl true
  def handle_info({:close_modal}, socket) do
    {:noreply, assign(socket, show_config_modal: false)}
  end

  @impl true
  def handle_info({:config_complete, config}, socket) do
    Logger.info("[WireframeEditorLive] Config complete: #{inspect(Map.delete(config, :uploaded_html))}")

    provider = Map.get(config, :provider)
    model = Map.get(config, :model)
    wireframe_sample = Map.get(config, :wireframe_sample, "blank")
    uploaded_html = Map.get(config, :uploaded_html)

    routine_id = socket.assigns.routine_id

    # Use uploaded HTML if available, otherwise load sample
    {html_content, sample_name} =
      if uploaded_html do
        {uploaded_html, "Uploaded HTML"}
      else
        load_sample_for_config(wireframe_sample)
      end

    # Select routine module based on routine_type
    routine_module =
      case socket.assigns.routine_type do
        :simple -> WireframeEditorRoutine
        :design -> WireframeDesignRoutine
      end

    user_context = %{
      routine_id: routine_id,
      llm_provider: provider,
      llm_model: model,
      max_tokens: 64000,
      temperature: 0.7,
      wireframe_html: html_content
    }

    case EngineManager.start_routine(routine_id, routine_module, user_context) do
      {:ok, _pid} ->
        Logger.info("[WireframeEditorLive] Started routine #{routine_id} with #{inspect(routine_module)}")
        Process.send_after(self(), :fetch_initial_state, 500)

        {:noreply,
         assign(socket,
           current_sample: sample_name,
           provider: provider,
           model: model,
           show_config_modal: false,
           agent_running: true,
           status: :running,
           messages: [],
           last_error: nil
         )}

      {:error, reason} ->
        Logger.error("[WireframeEditorLive] Failed to start routine: #{inspect(reason)}")

        {:noreply,
         assign(socket,
           last_error: "Failed to start routine: #{inspect(reason)}"
         )}
    end
  end

  @impl true
  def handle_info(:fetch_initial_state, socket) do
    routine_id = socket.assigns.routine_id
    designed = WireframeStateServer.get_designed(routine_id)
    running = WireframeStateServer.get_running(routine_id)
    screenshot = WireframeStateServer.get_screenshot(routine_id)

    # Get messages, status, and step info from routine state
    {messages, status, current_step, routine_module, execution_stack, step_module} =
      case EngineManager.get_routine_state(routine_id) do
        {:ok, state} ->
          msgs = get_in(state, [:context, :messages]) || []
          step = Map.get(state, :current_step)
          routine_status = Map.get(state, :routine_status, :running)
          routine_mod = Map.get(state, :current_routine_module)
          exec_stack = Map.get(state, :execution_stack, [])

          # Derive step_module from routine_definitions
          step_mod = get_step_module_from_state(state)

          {msgs, routine_status, step, routine_mod, exec_stack, step_mod}

        {:error, _} ->
          {[], :idle, nil, nil, [], nil}
      end

    # Start auto-refresh timer for debug panel
    if socket.assigns.mode == :debug do
      schedule_debug_refresh()
    end

    {:noreply,
     assign(socket,
       designed_state: designed,
       running_state: running,
       screenshot: screenshot,
       messages: messages,
       status: status,
       current_step: current_step,
       routine_module: routine_module,
       execution_stack: execution_stack,
       step_module: step_module
     )}
  end

  @impl true
  def handle_info(:refresh_debug_state, socket) do
    if socket.assigns.mode == :debug and socket.assigns.routine_id do
      routine_id = socket.assigns.routine_id
      designed = WireframeStateServer.get_designed(routine_id)
      running = WireframeStateServer.get_running(routine_id)
      screenshot = WireframeStateServer.get_screenshot(routine_id)

      schedule_debug_refresh()

      {:noreply,
       assign(socket,
         designed_state: designed,
         running_state: running,
         screenshot: screenshot
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:check_uploads, socket) do
    send_update(WireframeEditorWeb.UserInputComponent, id: "editor-chat-panel-input", check_uploads: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:clear_sent_feedback, component_id}, socket) do
    alias WireframeEditorWeb.UserInputComponent
    send_update(UserInputComponent, id: component_id, clear_sent_feedback: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_input_submitted, %{text: text, images: images} = data}, socket) do
    Logger.info("[WireframeEditorLive] User input: #{String.slice(text, 0, 50)}...")
    include_screenshot = Map.get(data, :include_screenshot, false)

    Engine.send_external_event(socket.assigns.routine_id, :user_input, %{
      text: text,
      images: images,
      include_screenshot: include_screenshot
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_messages, new_messages}, socket) do
    Logger.debug("[WireframeEditorLive] Received #{length(new_messages)} new message(s)")
    updated_messages = socket.assigns.messages ++ new_messages
    {:noreply, assign(socket, messages: updated_messages)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "routine_completed"} = event}, socket) do
    Logger.info("[WireframeEditorLive] Routine completed")
    error = get_in(event, [:metadata, :final_context, :error])
    status = if error, do: :error, else: :completed
    {:noreply, assign(socket, status: status, last_error: error, current_step: nil)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "error_occurred"} = event}, socket) do
    error_msg = get_in(event, [:metadata, :reason]) || "Unknown error"
    Logger.error("[WireframeEditorLive] Routine error: #{error_msg}")
    {:noreply, assign(socket, status: :error, last_error: error_msg, current_step: nil)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "step_started"} = event}, socket) do
    {:noreply,
     assign(socket,
       current_step: event.step_id,
       routine_module: Map.get(event, :routine_module),
       execution_stack: Map.get(event, :execution_stack, []),
       step_module: get_in(event, [:metadata, :step_module])
     )}
  end

  @impl true
  def handle_info({:routine_event, _event}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:save_config_to_localstorage, _config}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(message, socket) do
    Logger.debug("[WireframeEditorLive] Unhandled message: #{inspect(message)}")
    {:noreply, socket}
  end

  defp schedule_debug_refresh do
    Process.send_after(self(), :refresh_debug_state, 2000)
  end

  # Extracts step_module from Engine state by looking up current step in routine_definitions
  defp get_step_module_from_state(state) do
    current_routine_module = Map.get(state, :current_routine_module)
    current_step = Map.get(state, :current_step)
    routine_definitions = Map.get(state, :routine_definitions, %{})

    with routine_def when is_map(routine_def) <- Map.get(routine_definitions, current_routine_module),
         step_config when is_map(step_config) <- Map.get(routine_def, current_step) do
      Map.get(step_config, :type)
    else
      _ -> nil
    end
  end

  # ============================================================================
  # Render
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-50">
      <!-- Header -->
      <div class="bg-white border-b border-slate-200 shadow-sm flex-shrink-0">
        <div class="px-4 py-3 flex items-center justify-between">
          <div class="flex items-center gap-4">
            <h1 class="text-xl font-semibold text-slate-800">Wireframe Editor</h1>
            <%= if @current_sample do %>
              <div class="text-sm text-slate-600">
                <span class="font-medium"><%= @current_sample %></span>
              </div>
            <% end %>
            <%= if @mode == :debug do %>
              <span class="px-2 py-0.5 text-xs font-medium bg-amber-100 text-amber-700 rounded">Debug</span>
            <% end %>
          </div>
          <div class="flex items-center gap-3">
            <%= if @routine_id && @agent_running do %>
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
              <%= if @mode == :debug do %>
                <button
                  phx-click="refresh_state"
                  class="px-2 py-1 bg-purple-500 text-white text-xs rounded hover:bg-purple-600"
                >
                  Refresh State
                </button>
              <% end %>
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
              Home
            </a>
          </div>
        </div>
      </div>

      <!-- Config Modal -->
      <.live_component
        module={WireframeConfigModal}
        id="wireframe-config-modal"
        show={@show_config_modal}
      />

      <!-- ConfigStorage Hook -->
      <div phx-hook="ConfigStorage" id="config-storage" style="display: none;"></div>

      <!-- Main Content: Chat + Preview -->
      <%= if @agent_running && @routine_id do %>
        <div class={"flex-1 overflow-hidden flex #{if @mode == :debug, do: "flex-col", else: ""}"}>
          <!-- Chat + Preview Row -->
          <div class={"flex overflow-hidden #{if @mode == :debug, do: "h-1/2", else: "flex-1"}"} id="resizable-container">
            <!-- Left Panel: Chat -->
            <div
              class="border-r border-slate-300 bg-white flex flex-col"
              style={"width: #{@left_panel_width}%"}
            >
              <.live_component
                module={ChatPanel}
                id="editor-chat-panel"
                routine_id={@routine_id}
                messages={@messages}
                current_step={@current_step}
                routine_module={@routine_module}
                execution_stack={@execution_stack}
                step_module={@step_module}
                disabled={@status in [:completed, :error] || @last_error != nil}
                status={@status}
                last_error={@last_error}
                tool_display={@tool_display}
                show_system_messages={@mode == :debug}
              />
            </div>

            <!-- Resize Handle -->
            <div
              class="w-1 bg-slate-300 hover:bg-blue-500 cursor-col-resize transition-colors flex-shrink-0"
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

          <!-- Debug Panel (only in debug mode) -->
          <%= if @mode == :debug do %>
            <div class="h-1/2 border-t border-slate-300 bg-gray-100 overflow-hidden flex flex-col">
              <div class="px-3 py-1 bg-amber-100 border-b border-amber-200 flex-shrink-0">
                <span class="text-xs font-bold text-amber-800">Debug Panel</span>
              </div>
              <div class="flex-1 overflow-hidden grid grid-cols-3 gap-2 p-2">
                <!-- Designed State -->
                <div class="bg-white rounded shadow overflow-hidden flex flex-col">
                  <div class="px-2 py-1 bg-blue-50 border-b text-xs font-bold text-blue-800 flex-shrink-0">
                    Designed State
                  </div>
                  <pre class="flex-1 text-xs p-2 overflow-auto font-mono"><%= format_state(@designed_state) %></pre>
                </div>

                <!-- Running State -->
                <div class="bg-white rounded shadow overflow-hidden flex flex-col">
                  <div class="px-2 py-1 bg-green-50 border-b text-xs font-bold text-green-800 flex-shrink-0">
                    Running State
                  </div>
                  <%= if @running_state do %>
                    <pre class="flex-1 text-xs p-2 overflow-auto font-mono"><%= format_state(@running_state) %></pre>
                  <% else %>
                    <div class="flex-1 p-2 text-xs text-gray-500">No running state yet</div>
                  <% end %>
                </div>

                <!-- Screenshot -->
                <div class="bg-white rounded shadow overflow-hidden flex flex-col">
                  <div class="px-2 py-1 bg-purple-50 border-b text-xs font-bold text-purple-800 flex-shrink-0">
                    Screenshot
                  </div>
                  <div class="flex-1 p-2 overflow-auto">
                    <%= if @screenshot do %>
                      <img src={"data:image/png;base64,#{@screenshot}"} class="max-w-full border rounded" />
                    <% else %>
                      <div class="text-xs text-gray-500">No screenshot yet</div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Error Display -->
      <%= if @last_error do %>
        <div class="absolute bottom-4 left-4 right-4 max-w-2xl mx-auto z-50">
          <div class="bg-red-50 border border-red-200 rounded-lg p-3 shadow-lg">
            <div class="flex items-start">
              <div class="text-red-600 mr-2">Warning</div>
              <div class="text-sm text-red-800">
                <%= @last_error %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp format_state(nil), do: "nil"

  defp format_state(state) when is_map(state) do
    inspect(state, pretty: true, limit: 500, printable_limit: 2000)
  end

  defp format_state(other), do: inspect(other)

  defp load_sample_for_config(wireframe_sample) do
    case wireframe_sample do
      "blank" ->
        {nil, "Blank Page"}

      "login" ->
        case load_sample_html("simple") do
          {:ok, html} -> {html, "Login Form Example"}
          {:error, _} -> {nil, "Error"}
        end

      "dashboard" ->
        case load_sample_html("medium") do
          {:ok, html} -> {html, "Dashboard Layout Example"}
          {:error, _} -> {nil, "Error"}
        end

      _ ->
        {nil, "Blank Page"}
    end
  end

  defp load_sample_html(sample_id) do
    sample_files = %{
      "simple" => "wireframe_simple.html",
      "medium" => "wireframe_medium.html",
      "complex" => "wireframe_complex.html"
    }

    case Map.get(sample_files, sample_id) do
      nil ->
        {:error, "Unknown sample: #{sample_id}"}

      filename ->
        path = Path.join([:code.priv_dir(:koalemos), "wireframes", filename])

        case File.read(path) do
          {:ok, content} -> {:ok, content}
          {:error, reason} -> {:error, "File read error: #{inspect(reason)}"}
        end
    end
  end

  # Generate complete HTML from designed state
  defp generate_wireframe_html(designed) when is_map(designed) do
    dom_tree = Map.get(designed, :dom_tree)
    custom_css = Map.get(designed, :custom_css, %{})
    custom_variables = Map.get(designed, :custom_variables, %{})
    custom_functions = Map.get(designed, :custom_functions, %{})
    init_scripts = Map.get(designed, :init_scripts, %{})
    handlers = Map.get(designed, :handlers, %{})

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
        #{render_custom_css_block(custom_css)}
      </head>
      <body>
        #{render_dom_tree_html(dom_tree)}
        #{render_javascript_block(custom_variables, custom_functions, init_scripts, handlers)}
      </body>
    </html>
    """
  end

  defp generate_wireframe_html(_), do: "<html><body>Invalid wireframe state</body></html>"

  defp render_custom_css_block(custom_css) when map_size(custom_css) > 0 do
    css_rules =
      custom_css
      |> Enum.map(fn {selector, rules} ->
        if String.starts_with?(selector, "@keyframes") do
          # Keyframes have nested structure: %{"0%" => %{"prop" => "val"}, "50%" => %{...}}
          keyframe_rules = format_keyframe_rules(rules)
          "#{selector} { #{keyframe_rules} }"
        else
          rules_str = format_css_rules(rules)
          "#{selector} { #{rules_str} }"
        end
      end)
      |> Enum.join("\n      ")

    """
        <style>
          /* Custom CSS */
          #{css_rules}
        </style>
    """
  end

  defp render_custom_css_block(_), do: ""

  defp format_css_rules(rules) when is_binary(rules), do: rules

  defp format_css_rules(rules) when is_map(rules) do
    rules
    |> Enum.map(fn {prop, value} ->
      if is_binary(value), do: "#{prop}: #{value};", else: ""
    end)
    |> Enum.join(" ")
  end

  defp format_css_rules(_), do: ""

  # Format @keyframes rules: each keyframe selector gets its own block
  defp format_keyframe_rules(rules) when is_map(rules) do
    rules
    |> Enum.map(fn {keyframe_selector, properties} ->
      props_str = format_css_rules(properties)
      "#{keyframe_selector} { #{props_str} }"
    end)
    |> Enum.join(" ")
  end

  defp format_keyframe_rules(_), do: ""

  defp render_dom_tree_html(nil), do: ""

  defp render_dom_tree_html(tree) when is_map(tree) do
    tag = tree[:tag] || tree["tag"] || :div
    id = tree[:id] || tree["id"]
    classes = tree[:classes] || tree["classes"] || []
    attributes = tree[:attributes] || tree["attributes"] || %{}
    content = tree[:content] || tree["content"]
    children = tree[:children] || tree["children"] || []

    class_str = if is_list(classes) and length(classes) > 0, do: Enum.join(classes, " "), else: nil

    attrs =
      []
      |> maybe_add_attr("id", id)
      |> maybe_add_attr("class", class_str)

    attrs =
      Enum.reduce(attributes, attrs, fn {key, value}, acc ->
        maybe_add_attr(acc, key, value)
      end)

    attrs_str = if length(attrs) > 0, do: " " <> Enum.join(attrs, " "), else: ""

    children_html =
      children
      |> Enum.map(&render_dom_tree_html/1)
      |> Enum.join("")

    inner_html = if content, do: content, else: children_html

    "<#{tag}#{attrs_str}>#{inner_html}</#{tag}>"
  end

  defp render_dom_tree_html(text) when is_binary(text), do: text

  defp maybe_add_attr(attrs, _name, nil), do: attrs
  defp maybe_add_attr(attrs, _name, ""), do: attrs
  defp maybe_add_attr(attrs, name, value), do: attrs ++ ["#{name}=\"#{value}\""]

  defp render_javascript_block(variables, functions, init_scripts, handlers) do
    has_js =
      map_size(variables) > 0 or map_size(functions) > 0 or
        map_size(init_scripts) > 0 or map_size(handlers) > 0

    if has_js do
      """
        <script>
          // Global Variables
          #{render_variables(variables)}

          // Function Definitions
          #{render_functions(functions)}

          // Event Handlers
          document.addEventListener('DOMContentLoaded', function() {
            #{render_handlers(handlers)}
          });

          // Initialization Scripts
          #{render_init_scripts(init_scripts)}
        </script>
      """
    else
      ""
    end
  end

  defp render_variables(variables) when is_map(variables) and map_size(variables) > 0 do
    variables
    |> Enum.map(fn {name, value} ->
      json_value = Jason.encode!(value)
      "window.#{name} = #{json_value};"
    end)
    |> Enum.join("\n          ")
  end

  defp render_variables(_), do: ""

  defp render_functions(functions) when is_map(functions) and map_size(functions) > 0 do
    functions
    |> Enum.map(fn {name, code} ->
      "window.#{name} = #{code};"
    end)
    |> Enum.join("\n\n          ")
  end

  defp render_functions(_), do: ""

  defp render_init_scripts(init_scripts) when is_map(init_scripts) and map_size(init_scripts) > 0 do
    init_scripts
    |> Enum.sort_by(fn {key, _} -> key end)
    |> Enum.map(fn {_key, script} -> script end)
    |> Enum.join("\n          ")
  end

  defp render_init_scripts(_), do: ""

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
