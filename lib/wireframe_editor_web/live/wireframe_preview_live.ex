defmodule WireframeEditorWeb.WireframePreviewLive do
  @moduledoc """
  Wireframe preview page for V4 architecture.

  Key differences from V3:
  - No PubSub: Direct communication with StateServer via Registry
  - Registers with StateServer on "preview_ready" event
  - Receives messages directly from PreviewCoordinator

  ## Lifecycle

  1. Mount: Read designed state from StateServer
  2. Render: DOM tree from designed state
  3. Client: JS hook executes init scripts
  4. Client: Sends "preview_ready" event
  5. Server: Calls StateServer.register_preview(self())
  6. StateServer: Monitors this process, flushes pending queue

  ## Message Protocol

  Receives from PreviewCoordinator:
  - {:capture_state, coordinator_pid, from}
  - {:execute_interaction, coordinator_pid, from, args}
  - :reload_preview

  Sends to PreviewCoordinator:
  - {:state_captured, from, payload}
  - {:interaction_complete, from, result}

  ## Security Note: raw() HTML Rendering

  This module uses `raw()` to render user-designed HTML, CSS, and JavaScript.
  This is intentional - the purpose is to render a working wireframe page.

  **Current deployment model (single-user demo):** Safe. The user designs their
  own wireframes which execute in their own browser.

  **Multi-user deployment considerations:** If this becomes a shared service where
  users can view each other's wireframes, additional sandboxing would be needed:

  1. Render wireframes in a sandboxed iframe with `sandbox="allow-scripts"` only
     (remove `allow-same-origin` to prevent access to parent document)
  2. Serve wireframe preview from a different origin/subdomain
  3. Implement Content Security Policy (CSP) headers
  4. Consider server-side HTML sanitization for stored wireframes

  The iframe in wireframe_editor_live.ex currently uses:
  `sandbox="allow-scripts allow-same-origin allow-forms"`

  For multi-user: change to separate origin + `sandbox="allow-scripts allow-forms"`
  """

  use WireframeEditorWeb, :live_view
  require Logger
  require Koalemos.Log
  alias Koalemos.Log

  alias WireframeEditorWeb.Servers.WireframeStateServer

  @impl true
  def mount(%{"routine_id" => routine_id}, _session, socket) do
    Log.debug(:wireframe, "[WireframePreview] Mounting for routine: #{routine_id}")

    if WireframeStateServer.exists?(routine_id) do
      designed = WireframeStateServer.get_designed(routine_id)

      if is_nil(designed) do
        Logger.warning("[WireframePreview] No designed state for routine: #{routine_id}")
        {:ok, assign(socket, error: "No wireframe state initialized", routine_id: routine_id)}
      else
        socket =
          socket
          |> assign(routine_id: routine_id)
          |> assign(designed: designed)
          |> assign(registered: false)
          |> assign(error: nil)

        {:ok, socket}
      end
    else
      Logger.warning("[WireframePreview] No state server for routine: #{routine_id}")
      {:ok, assign(socket, error: "Wireframe state server not found", routine_id: routine_id)}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, error: "Missing routine_id parameter")}
  end

  # ============================================================================
  # Events from JavaScript
  # ============================================================================

  @impl true
  def handle_event("preview_ready", _payload, socket) do
    routine_id = socket.assigns.routine_id
    Log.debug(:wireframe, "[WireframePreview] Preview ready for #{routine_id}, registering")

    # Register with StateServer - this enables direct communication
    WireframeStateServer.register_preview(routine_id, self())

    {:noreply, assign(socket, registered: true)}
  end

  @impl true
  def handle_event("state_captured", payload, socket) do
    # Find the pending capture request and reply
    case socket.assigns[:pending_capture] do
      {coordinator_pid, from} ->
        Log.debug(:wireframe, "[WireframePreview] State captured, sending to coordinator")

        # Pass through payload with string keys converted to atoms
        # JS sends: dom_tree, variables, console_logs, viewport, scroll_position
        running =
          payload
          |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
          |> Map.new()

        send(coordinator_pid, {:state_captured, from, running})
        {:noreply, assign(socket, pending_capture: nil)}

      nil ->
        Logger.warning("[WireframePreview] State captured but no pending request")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("interaction_complete", result, socket) do
    case socket.assigns[:pending_interaction] do
      {coordinator_pid, from} ->
        Log.debug(:wireframe, "[WireframePreview] Interaction complete, sending to coordinator")
        send(coordinator_pid, {:interaction_complete, from, result})
        {:noreply, assign(socket, pending_interaction: nil)}

      nil ->
        Logger.warning("[WireframePreview] Interaction complete but no pending request")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("console_log", %{"log" => log}, socket) do
    Log.debug(:wireframe, "[WireframePreview] Console: #{inspect(log)}")
    {:noreply, socket}
  end

  # ============================================================================
  # Messages from PreviewCoordinator
  # ============================================================================

  @impl true
  def handle_info({:capture_state, coordinator_pid, from}, socket) do
    Log.debug(:wireframe, "[WireframePreview] Capture state request received")

    socket =
      socket
      |> assign(pending_capture: {coordinator_pid, from})
      |> push_event("capture_state", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:execute_interaction, coordinator_pid, from, args}, socket) do
    Log.debug(:wireframe, "[WireframePreview] Execute interaction request: #{inspect(args)}")

    socket =
      socket
      |> assign(pending_interaction: {coordinator_pid, from})
      |> push_event("execute_interaction", args)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:reload_preview, socket) do
    routine_id = socket.assigns.routine_id
    Log.debug(:wireframe, "[WireframePreview] Reload request received for #{routine_id}")

    # Full HTTP redirect forces complete remount
    {:noreply, redirect(socket, to: "/wireframe-preview/#{routine_id}")}
  end

  @impl true
  def handle_info(msg, socket) do
    Log.debug(:wireframe, "[WireframePreview] Unhandled message: #{inspect(msg)}")
    {:noreply, socket}
  end

  # ============================================================================
  # Render
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div phx-hook="WireframePreview" id="wireframe-preview" class="wireframe-preview-container">
      <!-- Custom CSS -->
      <%= if assigns[:designed] && assigns.designed[:custom_css] && map_size(assigns.designed.custom_css) > 0 do %>
        <style>
          <%= raw(render_custom_css(assigns.designed.custom_css)) %>
        </style>
      <% end %>

      <%= if assigns[:error] do %>
        <div style="padding: 20px; color: red; font-family: monospace;">
          <h3>Error Loading Preview</h3>
          <p><%= @error %></p>
          <p>Routine ID: <%= assigns[:routine_id] %></p>
        </div>
      <% else %>
        <%!-- phx-update="ignore" prevents LiveView from overwriting JS-created elements --%>
        <div id="wireframe-content" phx-update="ignore">
          <%= if assigns[:designed] && assigns.designed[:dom_tree] do %>
            <%= raw(render_dom_tree(assigns.designed.dom_tree)) %>
          <% else %>
            <div style="padding: 20px; color: gray;">
              <p>No wireframe content loaded</p>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Custom Functions -->
      <%= if assigns[:designed] && assigns.designed[:custom_functions] && map_size(assigns.designed.custom_functions) > 0 do %>
        <script>
          <%= raw(render_custom_functions(assigns.designed.custom_functions)) %>
        </script>
      <% end %>

      <!-- LiveView JavaScript Hook Data -->
      <script>
        window.__wireframeDataV4 = {
          routineId: '<%= assigns[:routine_id] %>',
          domTree: <%= raw(Jason.encode!(get_in(assigns, [:designed, :dom_tree]) || %{})) %>,
          initScripts: <%= raw(Jason.encode!(get_in(assigns, [:designed, :init_scripts]) || %{})) %>,
          customVariables: <%= raw(Jason.encode!(get_in(assigns, [:designed, :custom_variables]) || %{})) %>,
          handlers: <%= raw(Jason.encode!(get_in(assigns, [:designed, :handlers]) || %{})) %>
        };
        console.log('[WireframePreview] Data loaded:', window.__wireframeDataV4);
      </script>
    </div>
    """
  end

  # ============================================================================
  # Private: DOM Rendering
  # ============================================================================

  defp render_dom_tree(nil), do: ""

  defp render_dom_tree(tree) when is_map(tree) do
    tag = tree[:tag] || tree["tag"] || :div
    id = tree[:id] || tree["id"]
    classes = tree[:classes] || tree["classes"] || []
    attributes = tree[:attributes] || tree["attributes"] || %{}
    content = tree[:content] || tree["content"]
    children = tree[:children] || tree["children"] || []

    class_str =
      if is_list(classes) and length(classes) > 0 do
        Enum.join(classes, " ")
      else
        nil
      end

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
      |> Enum.map(&render_dom_tree/1)
      |> Enum.join("")

    inner_html = if content, do: content, else: children_html

    "<#{tag}#{attrs_str}>#{inner_html}</#{tag}>"
  end

  defp render_dom_tree(text) when is_binary(text), do: text

  defp maybe_add_attr(attrs, _name, nil), do: attrs
  defp maybe_add_attr(attrs, _name, ""), do: attrs
  defp maybe_add_attr(attrs, name, value), do: attrs ++ ["#{name}=\"#{value}\""]

  # ============================================================================
  # Private: CSS Rendering
  # ============================================================================

  defp render_custom_css(custom_css) when is_map(custom_css) do
    custom_css
    |> Enum.map(fn {selector, rules} ->
      rules_str = format_css_rules(rules)
      "#{selector} { #{rules_str} }"
    end)
    |> Enum.join("\n")
  end

  defp render_custom_css(_), do: ""

  # Format CSS rules - handle both string and map formats
  # Also handles nested maps defensively (LLM sometimes sends wrong structure)
  defp format_css_rules(rules) when is_binary(rules), do: rules
  defp format_css_rules(rules) when is_map(rules) do
    rules
    |> Enum.map(fn {prop, value} -> format_css_declaration(prop, value) end)
    |> Enum.join(" ")
  end
  defp format_css_rules(_), do: ""

  defp format_css_declaration(prop, value) when is_binary(value), do: "#{prop}: #{value};"
  defp format_css_declaration(_prop, value) when is_map(value) do
    # LLM sent nested map - flatten it
    value
    |> Enum.map(fn {p, v} -> if is_binary(v), do: "#{p}: #{v};", else: "" end)
    |> Enum.join(" ")
  end
  defp format_css_declaration(prop, value), do: "#{prop}: #{inspect(value)};"

  # ============================================================================
  # Private: Custom Functions Rendering
  # ============================================================================

  defp render_custom_functions(custom_functions) when is_map(custom_functions) do
    custom_functions
    |> Enum.sort_by(fn {name, _code} -> name end)
    |> Enum.map(fn {name, code} ->
      "window.#{name} = #{code};"
    end)
    |> Enum.join("\n\n")
  end

  defp render_custom_functions(_), do: ""
end
