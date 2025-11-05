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
    Logger.info("[WireframePreviewLive] Mounting for routine: #{routine_id}")

    # Subscribe to PubSub for wireframe updates
    Phoenix.PubSub.subscribe(
      Koalemos.PubSub,
      "wireframe_updates:#{routine_id}"
    )

    # Load initial DOM tree from routine context
    initial_tree = load_initial_dom_tree(routine_id)

    {:ok,
     socket
     |> assign(
       routine_id: routine_id,
       dom_tree: initial_tree,
       page_title: "Wireframe Preview"
     )}
  end

  @impl true
  def handle_info({:dom_tree_updated, new_tree, metadata}, socket) do
    Logger.info("[WireframePreviewLive] Received DOM tree update: #{inspect(metadata)}")

    {:noreply, assign(socket, :dom_tree, new_tree)}
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
        <style>
          /* Reset and base styles */
          * { box-sizing: border-box; }
          body { margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; }
        </style>
      </head>
      <body>
        <%= if @dom_tree do %>
          <%= render_dom_tree(@dom_tree) %>
        <% else %>
          <div style="padding: 2rem; text-align: center; color: #666;">
            <p>No wireframe loaded</p>
          </div>
        <% end %>
      </body>
    </html>
    """
  end

  # Private Helpers

  defp load_initial_dom_tree(routine_id) do
    Logger.debug("[WireframePreviewLive] Loading initial DOM tree for #{routine_id}")

    # Fetch lens_state from cache
    case Koalemos.Caches.WireframeStateCache.get_state(routine_id) do
      nil ->
        Logger.warning("[WireframePreviewLive] No lens_state found for routine #{routine_id}")
        nil

      lens_state ->
        Logger.info("[WireframePreviewLive] Found lens_state in cache for #{routine_id}")
        get_in(lens_state, [:designed, :dom_tree])
    end
  end

  defp render_dom_tree(nil), do: ""

  defp render_dom_tree(%{} = tree) do
    # Only wrap in Phoenix.HTML.raw at the top level
    Phoenix.HTML.raw(render_element_as_string(tree))
  end

  defp render_dom_tree(_invalid), do: ""

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
      inner_html = cond do
        content && is_binary(content) ->
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
    attrs = if classes && length(classes) > 0 do
      class_str = Enum.join(classes, " ")
      ["class=\"#{Plug.HTML.html_escape(class_str)}\"" | attrs]
    else
      attrs
    end

    # Add other attributes
    attrs = Enum.reduce(attributes, attrs, fn {key, value}, acc ->
      ["#{key}=\"#{Plug.HTML.html_escape(to_string(value))}\"" | acc]
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
end
