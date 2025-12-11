defmodule WireframeEditorWeb.WireframeEditorProductionLive do
  @moduledoc """
  V4 Production wireframe editor page.

  Clean V4 implementation with production features:
  - Config modal on mount (provider/model/sample selection)
  - Uses WireframeDesignRoutine
  - StateServer as single source of truth (no lens_state in LiveView)
  - Save/export wireframe as HTML
  - Resizable panels

  Route: /wireframe-editor-v4-production (will become /wireframe-editor after testing)
  """

  use WireframeEditorWeb, :live_view
  require Logger

  alias Koalemos.{EngineManager, Engine}
  alias WireframeEditorWeb.Routines.WireframeDesignRoutine
  alias WireframeEditorWeb.ChatPanel
  alias WireframeEditorWeb.WireframeConfigModal
  alias WireframeEditorWeb.Servers.WireframeStateServer

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Wireframe Editor",
       # Config modal state
       show_config_modal: true,
       current_sample: nil,
       # Configuration (from modal)
       provider: nil,
       model: nil,
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
       # UI state
       left_panel_width: 40,
       # Fixed display options (production defaults)
       tool_display: :inline,
       show_system_messages: false
     ), layout: false}
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

    {:noreply,
     assign(socket,
       show_config_modal: true,
       routine_id: nil,
       current_sample: nil,
       provider: nil,
       model: nil,
       messages: [],
       status: :idle,
       agent_running: false,
       last_error: nil
     )}
  end

  @impl true
  def handle_event("save_wireframe", _params, socket) do
    Logger.info("[WireframeEditorProduction] Generating wireframe download")

    case socket.assigns[:routine_id] do
      nil ->
        {:noreply, socket}

      routine_id ->
        # Get the designed state from StateServer
        designed = WireframeStateServer.get_designed(routine_id)

        if designed do
          try do
            html = generate_wireframe_html(designed)
            Logger.info("[WireframeEditorProduction] Generated HTML, length: #{String.length(html)} chars")
            filename = "wireframe_#{routine_id}_#{DateTime.utc_now() |> DateTime.to_unix()}.html"

            # Use blob download
            {:noreply,
             push_event(socket, "download", %{
               filename: filename,
               content: html,
               mime_type: "text/html"
             })}
          rescue
            e ->
              Logger.error("[WireframeEditorProduction] Failed to generate HTML: #{Exception.message(e)}")
              {:noreply, socket}
          end
        else
          Logger.warning("[WireframeEditorProduction] No designed state for download")
          {:noreply, socket}
        end
    end
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
    Logger.info("[WireframeEditorProduction] Config complete: #{inspect(config)}")

    provider = Map.get(config, :provider)
    model = Map.get(config, :model)
    wireframe_sample = Map.get(config, :wireframe_sample, "blank")

    # Generate unique routine_id
    routine_id = "wireframe-v4-#{:erlang.unique_integer([:positive])}"

    # Load wireframe HTML based on sample selection
    {html_content, sample_name} = load_sample_for_config(wireframe_sample)

    # Subscribe to routine events
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")
    end

    # Start WireframeDesignRoutine
    # The routine's setup will parse HTML and start StateServer
    user_context = %{
      routine_id: routine_id,
      llm_provider: provider,
      llm_model: model,
      max_tokens: 64000,
      temperature: 0.7,
      wireframe_html: html_content
    }

    case EngineManager.start_routine(routine_id, WireframeDesignRoutine, user_context) do
      {:ok, _pid} ->
        Logger.info("[WireframeEditorProduction] Started routine #{routine_id}")

        {:noreply,
         assign(socket,
           routine_id: routine_id,
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
        Logger.error("[WireframeEditorProduction] Failed to start routine: #{inspect(reason)}")

        {:noreply,
         assign(socket,
           last_error: "Failed to start routine: #{inspect(reason)}"
         )}
    end
  end

  @impl true
  def handle_info({:clear_sent_feedback, component_id}, socket) do
    alias WireframeEditorWeb.UserInputComponent
    send_update(UserInputComponent, id: component_id, clear_sent_feedback: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_input_submitted, %{text: text, images: images} = data}, socket) do
    Logger.info("[WireframeEditorProduction] User input: #{String.slice(text, 0, 50)}...")
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
    Logger.debug("[WireframeEditorProduction] Received #{length(new_messages)} new message(s)")
    updated_messages = socket.assigns.messages ++ new_messages
    {:noreply, assign(socket, messages: updated_messages)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "routine_completed"} = event}, socket) do
    Logger.info("[WireframeEditorProduction] Routine completed")
    error = get_in(event, [:metadata, :final_context, :error])
    status = if error, do: :error, else: :completed
    {:noreply, assign(socket, status: status, last_error: error, current_step: nil)}
  end

  @impl true
  def handle_info({:routine_event, %{event_type: "error_occurred"} = event}, socket) do
    error_msg = get_in(event, [:metadata, :reason]) || "Unknown error"
    Logger.error("[WireframeEditorProduction] Routine error: #{error_msg}")
    {:noreply, assign(socket, status: :error, current_step: nil)}
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
    # ConfigStorage hook handles this
    {:noreply, socket}
  end

  @impl true
  def handle_info(message, socket) do
    Logger.debug("[WireframeEditorProduction] Unhandled message: #{inspect(message)}")
    {:noreply, socket}
  end

  # ============================================================================
  # Render
  # ============================================================================

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
                <span class="font-medium"><%= @current_sample %></span>
              </div>
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
        <div class="flex-1 overflow-hidden flex" id="resizable-container">
          <!-- Left Panel: Chat -->
          <div
            class="border-r border-slate-300 bg-white flex flex-col"
            style={"width: #{@left_panel_width}%"}
          >
            <.live_component
              module={ChatPanel}
              id="v4-production-chat-panel"
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

          <!-- Right Panel: V4 Preview -->
          <div class="flex-1 bg-white flex flex-col overflow-hidden">
            <div class="border-b border-slate-200 px-4 py-2 bg-slate-50">
              <div class="flex items-center justify-between">
                <span class="text-sm font-medium text-slate-700">Live Preview</span>
                <span class="text-xs text-slate-500">Updates in real-time as you chat</span>
              </div>
            </div>
            <div class="flex-1 overflow-hidden">
              <iframe
                src={"/wireframe-preview-v4/#{@routine_id}"}
                class="w-full h-full border-0"
                id="wireframe-preview-v4"
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
        rules_str = format_css_rules(rules)
        "#{selector} { #{rules_str} }"
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

    attrs = Enum.reduce(attributes, attrs, fn {key, value}, acc ->
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
    has_js = map_size(variables) > 0 or map_size(functions) > 0 or
             map_size(init_scripts) > 0 or map_size(handlers) > 0

    if has_js do
      """
        <script>
          // Global Variables
          #{render_variables(variables)}

          // Function Definitions
          #{render_functions(functions)}

          // Event Handlers
          window.addEventListener('DOMContentLoaded', function() {
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
