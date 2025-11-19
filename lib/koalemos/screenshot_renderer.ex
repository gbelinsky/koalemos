defmodule Koalemos.ScreenshotRenderer do
  @moduledoc """
  Server-side screenshot rendering using Puppeteer.

  Converts lens_state DOM trees into standalone HTML documents and captures
  pixel-perfect screenshots using headless Chrome. This replaces client-side
  html-to-image which couldn't properly capture CSS gradients.

  ## Features
  - Full CSS gradient support (linear, radial, conic)
  - CSS transforms and filters
  - Tailwind CSS classes
  - Custom CSS rules
  - Proper font rendering

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

    # Prepare viewport options
    viewport = Keyword.get(opts, :viewport, %{width: 1280, height: 720})
    full_page = Keyword.get(opts, :full_page, false)

    puppeteer_opts = %{
      viewport: viewport,
      fullPage: full_page
    }

    # Call Puppeteer service via NodeJS bridge
    Logger.info("[ScreenshotRenderer] 🚀 Calling Puppeteer with viewport #{inspect(viewport)}")

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
  - Tailwind CSS CDN
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
    custom_css = get_in(lens_state, [source, :custom_css]) || get_in(lens_state, [:designed, :custom_css]) || %{}

    Logger.debug("[ScreenshotRenderer] Rendering from #{source} - has DOM: #{dom_tree != nil}, CSS rules: #{map_size(custom_css)}")

    # Render DOM tree to HTML string
    body_html = render_dom_tree(dom_tree)

    # Render custom CSS
    css_string = render_custom_css(custom_css)

    # Build complete HTML document
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Screenshot</title>

        <!-- Tailwind CSS CDN for class-based styling -->
        <script src="https://cdn.tailwindcss.com"></script>

        <style>
          /* Reset and base styles */
          * { box-sizing: border-box; }
          body { margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; }
        </style>
        #{if css_string != "", do: "<style>\n/* Custom CSS */\n#{css_string}\n</style>", else: ""}
      </head>
      <body>
        #{body_html}
      </body>
    </html>
    """
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
    render_element_as_string(tree)
  end

  defp render_dom_tree(_invalid), do: ""

  # Recursive function that renders DOM elements as HTML strings
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

  defp render_element_as_string(%{type: :text, content: content}) when is_binary(content) do
    Plug.HTML.html_escape(content)
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

  defp render_custom_css(_), do: ""
end
