defmodule WireframeEditorWeb.Services.ScreenshotRenderer do
  @moduledoc """
  Server-side screenshot rendering using Puppeteer.

  Converts lens_state DOM trees into standalone HTML documents and captures
  pixel-perfect screenshots using headless Chrome.

  ## Features
  - Full CSS gradient support (linear, radial, conic)
  - CSS transforms and filters
  - Custom CSS rules
  - Canvas element snapshots
  - Viewport and scroll position from running state

  ## Usage

      lens_state = %{designed: %{dom_tree: ..., custom_css: ...}}
      {:ok, base64_png} = ScreenshotRenderer.capture_from_lens_state(lens_state)
  """

  require Logger

  @doc """
  Capture a screenshot from a lens_state structure.

  Takes a lens_state map containing DOM tree and custom CSS, renders it to
  HTML, and captures a screenshot using Puppeteer.

  ## Parameters
  - `lens_state`: Map containing :designed and/or :running keys with :dom_tree and :custom_css
  - `opts`: Optional keyword list of options
    - `:use_live_dom` - Boolean, use :running DOM instead of :designed (default: false)
    - `:viewport` - Map with :width and :height (default: %{width: 1280, height: 720})
    - `:scroll_position` - Map with :x and :y scroll offsets (default: %{x: 0, y: 0})
    - `:full_page` - Boolean, capture full page or viewport (default: false)
    - `:routine_id` - String, for logging purposes

  ## Returns
  - `{:ok, base64_png}` - Base64-encoded PNG string (no data URI prefix)
  - `{:error, reason}` - Error tuple with reason
  """
  def capture_from_lens_state(lens_state, opts \\ []) do
    routine_id = Keyword.get(opts, :routine_id, "unknown")
    use_live_dom = Keyword.get(opts, :use_live_dom, false)
    dom_type = if use_live_dom, do: "LIVE", else: "DESIGNED"

    Logger.info(
      "[ScreenshotRenderer] 🎨 SERVER-SIDE SCREENSHOT REQUESTED for routine #{routine_id} using Puppeteer (#{dom_type} DOM)"
    )

    # Convert lens_state to standalone HTML (using live or designed DOM)
    html = render_html_from_state(lens_state, use_live_dom)

    Logger.debug(
      "[ScreenshotRenderer] Generated HTML from #{dom_type} DOM - length: #{String.length(html)} characters"
    )

    # Get viewport and scroll position from running state (captured from preview), or fall back to opts/defaults
    # Normalize keys since JS sends string keys but Puppeteer expects atom keys
    viewport =
      case get_in(lens_state, [:running, :viewport]) do
        %{"width" => w, "height" => h} -> %{width: w, height: h}
        %{width: _, height: _} = v -> v
        _ -> Keyword.get(opts, :viewport, %{width: 1280, height: 720})
      end

    scroll_position =
      case get_in(lens_state, [:running, :scroll_position]) do
        %{"x" => x, "y" => y} -> %{x: x, y: y}
        %{x: _, y: _} = s -> s
        _ -> Keyword.get(opts, :scroll_position, %{x: 0, y: 0})
      end

    full_page = Keyword.get(opts, :full_page, false)

    puppeteer_opts = %{
      viewport: viewport,
      fullPage: full_page,
      scrollPosition: scroll_position
    }

    # Call Puppeteer service via NodeJS bridge
    Logger.info(
      "[ScreenshotRenderer] 🚀 Calling Puppeteer with viewport #{inspect(viewport)}, scroll: #{inspect(scroll_position)}"
    )

    case call_puppeteer(html, puppeteer_opts) do
      {:ok, %{"base64" => base64, "width" => width, "height" => height}} ->
        Logger.info(
          "[ScreenshotRenderer] ✅ SERVER-SIDE screenshot captured successfully (#{width}x#{height}) for routine #{routine_id}"
        )

        {:ok, base64}

      {:error, reason} = error ->
        Logger.error(
          "[ScreenshotRenderer] ❌ SERVER-SIDE screenshot FAILED for routine #{routine_id}: #{inspect(reason)}"
        )

        error
    end
  end

  @doc """
  Convert a lens_state structure to a standalone HTML document.

  Creates a complete HTML document with:
  - DOCTYPE and HTML structure
  - Base reset styles
  - Custom CSS rules
  - Rendered DOM tree

  ## Parameters
  - `lens_state`: Map with :designed and/or :running state
  - `use_live_dom`: Boolean, if true use :running, else use :designed (default: false)

  Returns a string containing the complete HTML document.
  """
  def render_html_from_state(lens_state, use_live_dom \\ false) do
    # Extract components from lens_state (use live or designed)
    source = if use_live_dom, do: :running, else: :designed

    dom_tree = get_in(lens_state, [source, :dom_tree])

    custom_css =
      get_in(lens_state, [source, :custom_css]) ||
      get_in(lens_state, [:designed, :custom_css]) ||
      %{}

    Logger.debug("[ScreenshotRenderer] Rendering from #{source} - has DOM: #{dom_tree != nil}, CSS rules: #{map_size(custom_css)}")

    # Render DOM tree to HTML string
    body_html = render_dom_tree(dom_tree)

    # Render custom CSS
    css_string = render_custom_css(custom_css)

    # Build complete HTML document
    html = """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Screenshot</title>

        <style>
          /* Reset and base styles */
          * { box-sizing: border-box; }
          body { margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; }

          /* Canvas snapshot styling - preserve dimensions and prevent scaling */
          img.canvas-snapshot {
            display: block;
            max-width: none;
            image-rendering: crisp-edges;
          }
        </style>
        #{if css_string != "", do: "<style>\n/* Custom CSS */\n#{css_string}\n</style>", else: ""}
      </head>
      <body>
        #{body_html}
      </body>
    </html>
    """

    html
  end

  # Private Functions

  defp call_puppeteer(html, opts) do
    try do
      # Call the screenshot_service.js via NodeJS.Supervisor
      # Format: {module_name, function_name} matching the module.exports structure
      # Timeout set to 10 seconds to allow for browser launch and rendering
      result = NodeJS.call({"screenshot_service", :captureScreenshot}, [html, opts], timeout: 10_000)

      # NodeJS returns {:ok, data} or {:error, reason}
      case result do
        {:ok, %{"base64" => _, "width" => _, "height" => _} = success} ->
          {:ok, success}

        {:error, reason} ->
          {:error, "Puppeteer error: #{inspect(reason)}"}

        other ->
          {:error, "Invalid response from Puppeteer: #{inspect(other)}"}
      end
    rescue
      error ->
        {:error, "Puppeteer call failed: #{Exception.message(error)}"}
    catch
      :exit, reason ->
        {:error, "Puppeteer process exited: #{inspect(reason)}"}
    end
  end

  defp render_dom_tree(nil), do: ""

  defp render_dom_tree(%{} = tree) do
    # Normalize keys to atoms (JS sends string keys, designed state has atom keys)
    normalized = normalize_keys(tree)
    render_element_as_string(normalized)
  end

  defp render_dom_tree(_invalid), do: ""

  # Recursively normalize string keys to atoms for DOM tree
  defp normalize_keys(%{} = map) do
    map
    |> Enum.map(fn
      {"tag", v} -> {:tag, v}
      {"id", v} -> {:id, v}
      {"classes", v} -> {:classes, v}
      {"attributes", v} -> {:attributes, normalize_attributes(v)}
      {"content", v} -> {:content, v}
      {"children", v} when is_list(v) -> {:children, Enum.map(v, &normalize_keys/1)}
      {k, v} when is_atom(k) and k in [:tag, :id, :classes, :content] -> {k, v}
      {:attributes, v} -> {:attributes, normalize_attributes(v)}
      {:children, v} when is_list(v) -> {:children, Enum.map(v, &normalize_keys/1)}
      {k, v} -> {k, v}
    end)
    |> Map.new()
  end

  defp normalize_keys(other), do: other

  defp normalize_attributes(%{} = attrs) do
    # Keep attribute keys as strings (HTML attributes are strings)
    attrs
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
    |> Map.new()
  end

  defp normalize_attributes(other), do: other

  # Recursive function that renders DOM elements as HTML strings

  # Special handling for canvas elements - replace with image if snapshot available
  defp render_element_as_string(%{tag: "canvas"} = element) do
    # Extract canvas snapshot if available
    snapshot = get_in(element, [:attributes, "data-canvas-snapshot"])

    if snapshot && String.starts_with?(snapshot, "data:image/") do
      # Replace canvas with img element to preserve visual content in screenshot
      # Build img element attributes
      id = Map.get(element, :id)
      classes = Map.get(element, :classes, []) ++ ["canvas-snapshot"]

      # Preserve original canvas attributes except the snapshot data itself
      base_attributes =
        element
        |> Map.get(:attributes, %{})
        |> Map.delete("data-canvas-snapshot")
        |> Map.delete("data-canvas-error")

      # Add image-specific attributes
      img_attributes =
        Map.merge(base_attributes, %{
          "src" => snapshot,
          "alt" => "Canvas: #{id || "unnamed"}"
        })

      attrs = build_attributes_string(id, classes, img_attributes)

      "<img#{attrs} />"
    else
      # No snapshot available - render empty canvas (will appear blank)
      id = Map.get(element, :id)
      classes = Map.get(element, :classes, [])
      attributes = Map.get(element, :attributes, %{})
      attrs = build_attributes_string(id, classes, attributes)

      "<canvas#{attrs}></canvas>"
    end
  end

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

  defp render_element_as_string(invalid) do
    Logger.warning("[ScreenshotRenderer] Invalid element structure: #{inspect(invalid)}")
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

  defp render_custom_css(custom_css) when is_map(custom_css) do
    custom_css
    |> Enum.map(fn {selector, rules} ->
      # Handle both formats:
      # - String from LLM tool calls: "padding: 20px; color: blue"
      # - Map from parser: %{"padding" => "20px", "color" => "blue"}
      rules_str =
        case rules do
          str when is_binary(str) ->
            str

          map when is_map(map) ->
            Enum.map_join(map, "; ", fn {property, value} ->
              "#{property}: #{value}"
            end)
        end

      "#{selector} { #{rules_str}; }"
    end)
    |> Enum.join("\n")
  end

  defp render_custom_css(_), do: ""
end
