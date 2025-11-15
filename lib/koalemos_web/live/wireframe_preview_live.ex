defmodule KoalemosWeb.WireframePreviewLive do
  @moduledoc """
  LiveView that renders inside iframe for wireframe preview (M4 Sprint 4).

  Implements flo's proven LiveView-in-iframe architecture for live wireframe updates.

  ## Architecture

  1. **Mount:** Loads initial DOM tree from WireframeStateCache using routine_id
  2. **Subscribe:** Subscribes to PubSub topic "wireframe_updates:\#{routine_id}"
  3. **Render:** Recursively renders DOM tree as HTML with proper escaping
  4. **Update:** Receives {:dom_tree_updated, tree, metadata} messages via PubSub

  ## Key Features

  - **Live updates** without iframe reload (preserves JavaScript state)
  - **Cache-backed initialization** solves timing issue (broadcast before mount)
  - **Safe HTML rendering** using Plug.HTML.html_escape for attributes and content
  - **Recursive DOM rendering** supports nested elements with children
  - **PubSub integration** enables real-time updates from tool execution

  ## Why LiveView instead of static srcdoc?

  - Enables smooth transitions when agent modifies wireframe
  - Preserves JavaScript state during updates
  - Sets foundation for interactive features (element selection, click handlers)
  - Proven pattern from flo's wireframe editor

  ## Future Enhancements (Sprint 5+)

  - Push events to JavaScript hook for event handler attachment
  - Element selection and highlighting
  - Live CSS updates without full re-render
  - Diff-based updates for better performance

  Route: /wireframe-preview/:routine_id
  """
  use KoalemosWeb, :live_view
  require Logger

  @impl true
  def mount(%{"routine_id" => routine_id} = _params, _session, socket) do
    Logger.info("[WireframePreviewLive] 🔄 Mounting for routine: #{routine_id}")

    # Subscribe to PubSub for wireframe updates, snapshots, and interactions
    Phoenix.PubSub.subscribe(
      Koalemos.PubSub,
      "wireframe_updates:#{routine_id}"
    )

    # Load initial state from cache
    {initial_tree, custom_css, custom_functions, custom_variables, init_scripts, handlers} =
      load_initial_state(routine_id)

    Logger.info(
      "[WireframePreviewLive] Initial mount - dom_tree present: #{not is_nil(initial_tree)}, css entries: #{map_size(custom_css)}, functions: #{map_size(custom_functions)}, variables: #{map_size(custom_variables)}, init_scripts: #{map_size(init_scripts)}, handlers: #{map_size(handlers)}"
    )

    socket =
      socket
      |> assign(
        routine_id: routine_id,
        dom_tree: initial_tree,
        custom_css: custom_css,
        custom_functions: custom_functions,
        custom_variables: custom_variables,
        init_scripts: init_scripts,
        handlers: handlers,
        page_title: "Wireframe Preview"
      )

    # Push initial handlers if present (Sprint 6)
    socket =
      if map_size(handlers) > 0 do
        Logger.debug(
          "[WireframePreviewLive] Pushing initial handlers on mount: #{inspect(Map.keys(handlers))}"
        )

        push_event(socket, "update_handlers", %{handlers: handlers})
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_info({:dom_tree_updated, new_tree, metadata}, socket) do
    Logger.info("[WireframePreviewLive] Received DOM tree update: #{inspect(metadata)}")

    # Also reload CSS and JavaScript from cache in case they changed
    routine_id = socket.assigns.routine_id

    {_, custom_css, custom_functions, custom_variables, init_scripts, handlers} =
      load_initial_state(routine_id)

    # Push JavaScript updates to client if they changed (Sprint 6 fix)
    socket =
      push_javascript_updates(socket, custom_variables, custom_functions, handlers, init_scripts)

    {:noreply,
     assign(socket,
       dom_tree: new_tree,
       custom_css: custom_css,
       custom_functions: custom_functions,
       custom_variables: custom_variables,
       init_scripts: init_scripts,
       handlers: handlers
     )}
  end

  # Handle snapshot request from WireframeEditor lens (Sprint 7)
  @impl true
  def handle_info({:snapshot_request, requested_id, opts}, socket) do
    Logger.info(
      "[WireframePreviewLive] Received snapshot_request for #{requested_id}, my routine_id: #{socket.assigns.routine_id}"
    )

    if socket.assigns.routine_id == requested_id do
      Logger.info("[WireframePreviewLive] Snapshot requested, triggering client capture")
      skip_screenshot = Keyword.get(opts || [], :skip_screenshot, false)
      variable_names = Map.keys(socket.assigns.custom_variables)

      {:noreply,
       push_event(socket, "capture_state", %{
         skip_screenshot: skip_screenshot,
         variable_names: variable_names
       })}
    else
      Logger.warning(
        "[WireframePreviewLive] Snapshot request for wrong routine_id: #{requested_id} != #{socket.assigns.routine_id}"
      )

      {:noreply, socket}
    end
  end

  # Handle interaction execution request from WireframeEditor (Sprint 7 Phase 3)
  @impl true
  def handle_info({:execute_interaction, args}, socket) do
    Logger.debug("[WireframePreviewLive] Executing interaction: #{inspect(args)}")
    {:noreply, push_event(socket, "execute_interaction", args)}
  end

  # Handle state snapshot data from client (Sprint 7)
  @impl true
  def handle_event("state_snapshot", snapshot_data, socket) do
    routine_id = socket.assigns.routine_id

    Logger.debug("[WireframePreviewLive] Received state snapshot from client")

    # Store DOM in DOMStateCache (use format expected by cache)
    if dom_tree = snapshot_data["dom_tree"] do
      cache_entry = %{
        "liveDOMTree" => dom_tree,
        "changeType" => "snapshot",
        "timestamp" => System.system_time(:millisecond)
      }

      # Include variables if captured
      cache_entry =
        if variables = snapshot_data["variables"] do
          Logger.info(
            "[WireframePreviewLive] 📦 Storing #{map_size(variables)} variable values in cache: #{inspect(variables)}"
          )

          Map.put(cache_entry, "variables", variables)
        else
          Logger.warning("[WireframePreviewLive] ⚠️  No variables in snapshot_data")
          cache_entry
        end

      Koalemos.Caches.DOMStateCache.add_dom_state(routine_id, cache_entry)
      Logger.info("[WireframePreviewLive] ✓ Cache entry stored with keys: #{inspect(Map.keys(cache_entry))}")
    end

    # Store console messages in ConsoleCache (if any new messages)
    if console_messages = snapshot_data["console_messages"] do
      Logger.debug(
        "[WireframePreviewLive] Storing #{length(console_messages)} console messages in ConsoleCache"
      )

      Enum.each(console_messages, fn msg ->
        # Convert string keys to atom keys (JavaScript sends strings, ConsoleCache expects atoms)
        atomized_msg = %{
          level: msg["level"],
          message: msg["message"],
          timestamp: msg["timestamp"]
        }

        Koalemos.Caches.ConsoleCache.add_message(routine_id, atomized_msg)
      end)
    end

    # Store screenshot in ScreenshotCache
    if screenshot_data = snapshot_data["screenshot"] do
      Koalemos.Caches.ScreenshotCache.put(routine_id, screenshot_data)
    end

    # Broadcast ready notification
    Phoenix.PubSub.broadcast(
      Koalemos.PubSub,
      "snapshot:response:#{routine_id}",
      {:snapshot_ready, routine_id, DateTime.utc_now()}
    )

    {:noreply, socket}
  end

  # Handle interaction completion from client (Sprint 7 Phase 3)
  @impl true
  def handle_event("interaction_complete", result, socket) do
    routine_id = socket.assigns.routine_id

    Logger.info("[WireframePreviewLive] Interaction completed: #{inspect(result)}")

    # Broadcast completion notification (for future use / debugging)
    # Note: Currently fire-and-forget, not blocking like snapshots
    Phoenix.PubSub.broadcast(
      Koalemos.PubSub,
      "interaction:response:#{routine_id}",
      {:interaction_complete, result}
    )

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Wireframe Preview</title>
        
    <!-- Tailwind CSS CDN for class-based styling -->
        <script src="https://cdn.tailwindcss.com">
        </script>

        <style>
          /* Reset and base styles */
          * { box-sizing: border-box; }
          body { margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; }
        </style>
        <%= if @custom_css && map_size(@custom_css) > 0 do %>
          <style>
            /* Custom CSS from wireframe */
            <%= raw(render_custom_css(@custom_css)) %>
          </style>
        <% end %>
      </head>
      <body>
        <!-- Early console interception (Sprint 7 Phase 4) - must run BEFORE init scripts -->
        <script>
          // Store original console methods before any wireframe code runs
          window.__originalConsole = {
            log: console.log.bind(console),
            warn: console.warn.bind(console),
            error: console.error.bind(console)
          };

          // Log that we're starting interception (using original console)
          window.__originalConsole.log('[ConsoleInterception] Starting console capture - all subsequent logs will be buffered');

          // Buffer for captured console messages
          window.__consoleBuffer = [];

          // Intercept console methods
          ['log', 'warn', 'error'].forEach(function(level) {
            var original = window.__originalConsole[level];
            console[level] = function() {
              // Still show in browser console
              original.apply(console, arguments);

              // Convert arguments to array and buffer
              var args = Array.prototype.slice.call(arguments);
              var message = args.map(function(arg) {
                if (typeof arg === 'string') return arg;
                if (arg instanceof Error) return arg.name + ': ' + arg.message + '\\n' + (arg.stack || '');
                try { return JSON.stringify(arg); } catch(e) { return String(arg); }
              }).join(' ');

              window.__consoleBuffer.push({
                level: level,
                message: message,
                timestamp: Date.now()
              });

              // Limit buffer size
              if (window.__consoleBuffer.length > 100) {
                window.__consoleBuffer.shift();
              }
            };
          });

          // Log that interception is active (using original console so NOT captured)
          window.__originalConsole.log('[ConsoleInterception] Console buffering is now active');
        </script>
        
    <!-- JavaScript Updater Hook (Sprint 6) - dynamically updates variables/functions -->
        <div phx-hook="JavaScriptUpdater" id="js-updater" style="display: none;"></div>
        
    <!-- ScreenshotCapture Hook (Sprint 7 Phase 5) - enables screenshot capture for state snapshots -->
        <div phx-hook="ScreenshotCapture" id="wireframe-screenshot-target" style="display: none;">
        </div>

        <%= if @dom_tree do %>
          {render_dom_tree(@dom_tree)}
        <% else %>
          <div style="padding: 2rem; text-align: center; color: #666;">
            <p>No wireframe loaded</p>
          </div>
        <% end %>
        
    <!-- JavaScript Rendering (Sprint 6) -->
        <%= if has_javascript_content?(@custom_variables, @custom_functions, @init_scripts, @handlers) do %>
          <script>
            // ===== Global Variables =====
            <%= raw(render_custom_variables(@custom_variables)) %>

            // ===== Function Definitions =====
            <%= raw(render_custom_functions(@custom_functions)) %>

            // ===== Event Handler Attachment =====
            // NOTE: Handlers are attached dynamically via JavaScriptUpdater hook
            // This ensures proper cleanup when handlers change

            // ===== Initialization Scripts =====
            <%= raw(render_init_scripts(@init_scripts)) %>
          </script>
        <% end %>
      </body>
    </html>
    """
  end

  # Private Helpers

  # Push JavaScript updates to client if variables/functions/handlers changed (Sprint 6)
  defp push_javascript_updates(
         socket,
         new_variables,
         new_functions,
         new_handlers,
         new_init_scripts
       ) do
    old_variables = socket.assigns[:custom_variables] || %{}
    old_functions = socket.assigns[:custom_functions] || %{}
    old_handlers = socket.assigns[:handlers] || %{}
    old_init_scripts = socket.assigns[:init_scripts] || %{}

    Logger.debug("[WireframePreviewLive] Checking JavaScript changes...")
    Logger.debug("  Old variables: #{inspect(old_variables)}")
    Logger.debug("  New variables: #{inspect(new_variables)}")
    Logger.debug("  Variables equal? #{old_variables == new_variables}")
    Logger.debug("  Old handlers: #{inspect(old_handlers)}")
    Logger.debug("  New handlers: #{inspect(new_handlers)}")
    Logger.debug("  Handlers equal? #{old_handlers == new_handlers}")
    Logger.debug("  Old init_scripts: #{inspect(Map.keys(old_init_scripts))}")
    Logger.debug("  New init_scripts: #{inspect(Map.keys(new_init_scripts))}")
    Logger.debug("  Init scripts equal? #{old_init_scripts == new_init_scripts}")

    # Check if variables changed
    socket =
      if new_variables != old_variables && map_size(new_variables) > 0 do
        Logger.debug(
          "[WireframePreviewLive] ✅ Pushing variable updates: #{inspect(Map.keys(new_variables))}"
        )

        push_event(socket, "update_variables", %{variables: new_variables})
      else
        Logger.debug(
          "[WireframePreviewLive] ❌ NOT pushing variables (equal: #{old_variables == new_variables}, size: #{map_size(new_variables)})"
        )

        socket
      end

    # Check if functions changed
    socket =
      if new_functions != old_functions && map_size(new_functions) > 0 do
        Logger.debug(
          "[WireframePreviewLive] ✅ Pushing function updates: #{inspect(Map.keys(new_functions))}"
        )

        push_event(socket, "update_functions", %{functions: new_functions})
      else
        Logger.debug(
          "[WireframePreviewLive] ❌ NOT pushing functions (equal: #{old_functions == new_functions}, size: #{map_size(new_functions)})"
        )

        socket
      end

    # Check if handlers changed
    socket =
      if new_handlers != old_handlers && map_size(new_handlers) > 0 do
        Logger.debug(
          "[WireframePreviewLive] ✅ Pushing handler updates: #{inspect(Map.keys(new_handlers))}"
        )

        push_event(socket, "update_handlers", %{handlers: new_handlers})
      else
        Logger.debug(
          "[WireframePreviewLive] ❌ NOT pushing handlers (equal: #{old_handlers == new_handlers}, size: #{map_size(new_handlers)})"
        )

        socket
      end

    # Check if init scripts changed - reload page for clean initialization
    # TODO BACKLOG: Implement "soft reload" (reset state without browser reload)
    socket =
      if new_init_scripts != old_init_scripts do
        Logger.debug("[WireframePreviewLive] ✅ Init scripts changed - triggering page reload")
        push_event(socket, "reload_page", %{})
      else
        socket
      end

    socket
  end

  defp load_initial_state(routine_id) do
    Logger.debug("[WireframePreviewLive] Loading initial state for #{routine_id}")

    # Fetch lens_state from cache
    case Koalemos.Caches.WireframeStateCache.get_state(routine_id) do
      nil ->
        Logger.warning("[WireframePreviewLive] No lens_state found for routine #{routine_id}")
        {nil, %{}, %{}, %{}, %{}, %{}}

      lens_state ->
        Logger.info("[WireframePreviewLive] Found lens_state in cache for #{routine_id}")
        dom_tree = get_in(lens_state, [:designed, :dom_tree])
        custom_css = get_in(lens_state, [:designed, :custom_css]) || %{}
        custom_functions = get_in(lens_state, [:designed, :custom_functions]) || %{}
        custom_variables = get_in(lens_state, [:designed, :custom_variables]) || %{}
        init_scripts = get_in(lens_state, [:designed, :init_scripts]) || %{}
        handlers = get_in(lens_state, [:designed, :handlers]) || %{}
        {dom_tree, custom_css, custom_functions, custom_variables, init_scripts, handlers}
    end
  end

  def render_custom_css(custom_css) when is_map(custom_css) do
    custom_css
    |> Enum.map(fn {selector, rules} ->
      # Handle both string format and structured format
      rules_str =
        case rules do
          # String format: "property: value; property: value"
          str when is_binary(str) ->
            str

          # Map format: %{"property" => "value", ...}
          map when is_map(map) ->
            Enum.map_join(map, "; ", fn {property, value} ->
              "#{property}: #{value}"
            end)

          # List format: [{"property", "value"}, ...]
          list when is_list(list) ->
            Enum.map_join(list, "; ", fn {property, value} ->
              "#{property}: #{value}"
            end)
        end

      "#{selector} { #{rules_str}; }"
    end)
    |> Enum.join("\n")
  end

  def render_custom_css(_), do: ""

  def render_dom_tree(nil), do: ""

  def render_dom_tree(%{} = tree) do
    # Only wrap in Phoenix.HTML.raw at the top level
    Phoenix.HTML.raw(render_element_as_string(tree))
  end

  def render_dom_tree(_invalid), do: ""

  # Recursive function that returns plain strings (no {:safe, _} tuples)
  defp render_element_as_string(%{tag: tag} = element) when is_binary(tag) do
    # Extract element properties
    id = Map.get(element, :id)
    classes = Map.get(element, :classes, [])
    attributes = Map.get(element, :attributes, %{})
    content = Map.get(element, :content)
    children = Map.get(element, :children, [])

    # Build attributes string
    attrs = build_attributes_string(id, classes, attributes)

    # Render based on whether it's self-closing
    if self_closing_tag?(tag) do
      "<#{tag}#{attrs} />"
    else
      # Render with children or content
      # Note: Filter out "nil" string because Observer.make_serializable converts atom nil to string "nil"
      inner_html =
        cond do
          is_binary(content) && content != "" && content != "nil" ->
            Plug.HTML.html_escape(content)

          is_list(children) && length(children) > 0 ->
            children
            |> Enum.map(&render_element_as_string/1)
            |> Enum.join("")

          true ->
            ""
        end

      "<#{tag}#{attrs}>#{inner_html}</#{tag}>"
    end
  end

  defp render_element_as_string(%{type: :text, content: content}) when is_binary(content) do
    Plug.HTML.html_escape(content)
  end

  defp render_element_as_string(invalid) do
    Logger.warning("[WireframePreviewLive] Invalid element structure: #{inspect(invalid)}")
    ""
  end

  defp build_attributes_string(id, classes, attributes) do
    attrs = []

    # Add id if present
    attrs = if id, do: ["id=\"#{Plug.HTML.html_escape(id)}\"" | attrs], else: attrs

    # Add classes if present
    attrs =
      if classes && length(classes) > 0 do
        class_str = Enum.join(classes, " ")
        ["class=\"#{Plug.HTML.html_escape(class_str)}\"" | attrs]
      else
        attrs
      end

    # Add other attributes (with special handling for boolean-valued attributes)
    attrs =
      Enum.reduce(attributes, attrs, fn {key, value}, acc ->
        if is_boolean(value) do
          # Boolean-valued attributes: render without value if true, omit if false
          if value do
            ["#{key}" | acc]
          else
            acc
          end
        else
          # Regular attributes: always render with value
          ["#{key}=\"#{Plug.HTML.html_escape(to_string(value))}\"" | acc]
        end
      end)

    if length(attrs) > 0 do
      " " <> Enum.join(Enum.reverse(attrs), " ")
    else
      ""
    end
  end

  defp self_closing_tag?(tag) when is_binary(tag) do
    tag in ~w(area base br col embed hr img input link meta param source track wbr)
  end

  # JavaScript Rendering Functions (Sprint 6)

  defp has_javascript_content?(variables, functions, init_scripts, handlers) do
    (is_map(variables) && map_size(variables) > 0) ||
      (is_map(functions) && map_size(functions) > 0) ||
      (is_map(init_scripts) && map_size(init_scripts) > 0) ||
      (is_map(handlers) && map_size(handlers) > 0)
  end

  def render_custom_variables(variables) when is_map(variables) and map_size(variables) > 0 do
    variables
    |> Enum.map(fn {name, value} ->
      # Encode value as JSON for safe JavaScript representation
      json_value = Jason.encode!(value)
      "window.#{name} = #{json_value};"
    end)
    |> Enum.join("\n")
  end

  def render_custom_variables(_), do: ""

  def render_custom_functions(functions) when is_map(functions) and map_size(functions) > 0 do
    functions
    |> Enum.map(fn {name, code} ->
      # Functions are stored as arrow function code: "function() { ... }"
      # Render as: window.funcName = function() { ... };
      "window.#{name} = #{code};"
    end)
    |> Enum.join("\n\n")
  end

  def render_custom_functions(_), do: ""

  def render_init_scripts(init_scripts)
       when is_map(init_scripts) and map_size(init_scripts) > 0 do
    # Execute init scripts, handling both initial load and reload cases
    scripts_code =
      init_scripts
      |> Enum.map(fn {_name, code} -> code end)
      |> Enum.join("\n\n")

    """
    // Execute immediately if DOM already loaded (e.g., after reload)
    // Otherwise wait for DOMContentLoaded
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function() {
        #{scripts_code}
      });
    } else {
      #{scripts_code}
    }
    """
  end

  def render_init_scripts(_), do: ""
end
