defmodule WireframeEditorWeb.ScreenshotTestLive do
  @moduledoc """
  Screenshot test page demonstrating server-side Puppeteer screenshot capture.

  Features:
  - Load sample wireframes from priv/wireframes/
  - Parse HTML into lens_state format
  - Capture screenshots via ScreenshotRenderer (Puppeteer)
  - Display captured screenshots with metadata

  Route: /test/screenshot
  """
  use WireframeEditorWeb, :live_view
  require Logger

  alias WireframeEditorWeb.Parsers.HTMLParser
  alias WireframeEditorWeb.Services.ScreenshotRenderer

  @impl true
  def mount(_params, _session, socket) do
    wireframes = list_wireframes()

    {:ok,
     assign(socket,
       page_title: "Screenshot Test",
       wireframes: wireframes,
       selected_wireframe: nil,
       lens_state: nil,
       screenshot: nil,
       screenshot_meta: nil,
       loading: false,
       error: nil
     )}
  end

  @impl true
  def handle_event("select_wireframe", %{"wireframe" => filename}, socket) do
    socket = assign(socket, loading: true, error: nil)

    case load_wireframe(filename) do
      {:ok, lens_state} ->
        {:noreply,
         assign(socket,
           selected_wireframe: filename,
           lens_state: lens_state,
           screenshot: nil,
           screenshot_meta: nil,
           loading: false
         )}

      {:error, reason} ->
        {:noreply,
         assign(socket,
           error: "Failed to load wireframe: #{inspect(reason)}",
           loading: false
         )}
    end
  end

  @impl true
  def handle_event("capture_screenshot", _params, socket) do
    lens_state = socket.assigns.lens_state

    if is_nil(lens_state) do
      {:noreply, assign(socket, error: "No wireframe loaded")}
    else
      socket = assign(socket, loading: true, error: nil)

      case ScreenshotRenderer.capture_from_lens_state(lens_state, routine_id: "screenshot-test") do
        {:ok, base64_png} ->
          # Calculate size
          size_kb = round(byte_size(base64_png) / 1024)

          {:noreply,
           assign(socket,
             screenshot: base64_png,
             screenshot_meta: %{
               size_kb: size_kb,
               captured_at: DateTime.utc_now()
             },
             loading: false
           )}

        {:error, reason} ->
          {:noreply,
           assign(socket,
             error: "Screenshot capture failed: #{inspect(reason)}",
             loading: false
           )}
      end
    end
  end

  @impl true
  def handle_event("clear_screenshot", _params, socket) do
    {:noreply, assign(socket, screenshot: nil, screenshot_meta: nil)}
  end

  # List available wireframe files
  defp list_wireframes do
    path = Path.join(:code.priv_dir(:koalemos), "wireframes")

    case File.ls(path) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".html"))
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  # Load and parse wireframe file into lens_state format
  defp load_wireframe(filename) do
    path = Path.join([:code.priv_dir(:koalemos), "wireframes", filename])

    case HTMLParser.parse_file(path) do
      {:ok, parsed} ->
        # Convert parsed HTML to lens_state format
        # Extract inline CSS from style elements
        custom_css = extract_custom_css(parsed.style_elements)

        lens_state = %{
          designed: %{
            dom_tree: parsed.dom_tree,
            custom_css: custom_css
          }
        }

        {:ok, lens_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Convert style_elements to custom_css map format
  # For simplicity, we'll use a single "body" selector with all inline styles
  defp extract_custom_css(style_elements) do
    inline_css =
      style_elements
      |> Enum.filter(&(&1.type == :inline))
      |> Enum.map(& &1.content)
      |> Enum.join("\n")

    if inline_css != "" do
      # Parse the CSS into selector => rules format
      # This is a simplified parser - just extract rule blocks
      parse_css_to_map(inline_css)
    else
      %{}
    end
  end

  # Simple CSS parser to extract selector => rules
  defp parse_css_to_map(css_string) do
    # Match CSS rule blocks: selector { rules }
    ~r/([^{]+)\{([^}]+)\}/
    |> Regex.scan(css_string)
    |> Enum.map(fn [_full, selector, rules] ->
      {String.trim(selector), String.trim(rules)}
    end)
    |> Enum.into(%{})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 p-6">
      <div class="max-w-6xl mx-auto">
        <!-- Header -->
        <div class="mb-6">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-slate-800">Screenshot Test</h1>
              <p class="text-slate-600 mt-1">
                Server-side screenshot capture via Puppeteer
              </p>
            </div>
            <a
              href="/test"
              class="text-sm text-blue-600 hover:text-blue-800 font-medium"
            >
              ← Test Pages
            </a>
          </div>
        </div>

        <!-- Error Display -->
        <%= if @error do %>
          <div class="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg text-red-700">
            <%= @error %>
          </div>
        <% end %>

        <!-- Main Content -->
        <div class="grid grid-cols-2 gap-6">
          <!-- Left: Wireframe Selection & Preview -->
          <div class="space-y-4">
            <!-- Wireframe Selector -->
            <div class="bg-white rounded-lg shadow p-4">
              <h2 class="text-lg font-semibold text-slate-800 mb-3">Select Wireframe</h2>
              <div class="flex flex-wrap gap-2">
                <%= for wireframe <- @wireframes do %>
                  <button
                    phx-click="select_wireframe"
                    phx-value-wireframe={wireframe}
                    class={[
                      "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
                      if(@selected_wireframe == wireframe,
                        do: "bg-blue-600 text-white",
                        else: "bg-slate-100 text-slate-700 hover:bg-slate-200"
                      )
                    ]}
                  >
                    <%= wireframe %>
                  </button>
                <% end %>
              </div>
            </div>

            <!-- DOM Tree Preview -->
            <div class="bg-white rounded-lg shadow p-4">
              <h2 class="text-lg font-semibold text-slate-800 mb-3">Parsed DOM Tree</h2>
              <%= if @lens_state do %>
                <div class="bg-slate-50 rounded p-3 max-h-96 overflow-auto">
                  <pre class="text-xs text-slate-600 font-mono whitespace-pre-wrap"><%= inspect(@lens_state.designed.dom_tree, pretty: true, limit: :infinity) %></pre>
                </div>
              <% else %>
                <p class="text-slate-500 italic">Select a wireframe to see parsed DOM</p>
              <% end %>
            </div>

            <!-- CSS Preview -->
            <%= if @lens_state && map_size(@lens_state.designed.custom_css) > 0 do %>
              <div class="bg-white rounded-lg shadow p-4">
                <h2 class="text-lg font-semibold text-slate-800 mb-3">
                  Custom CSS (<%= map_size(@lens_state.designed.custom_css) %> rules)
                </h2>
                <div class="bg-slate-50 rounded p-3 max-h-48 overflow-auto">
                  <pre class="text-xs text-slate-600 font-mono whitespace-pre-wrap"><%= format_css(@lens_state.designed.custom_css) %></pre>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Right: Screenshot Capture -->
          <div class="space-y-4">
            <!-- Capture Controls -->
            <div class="bg-white rounded-lg shadow p-4">
              <h2 class="text-lg font-semibold text-slate-800 mb-3">Screenshot Capture</h2>
              <div class="flex items-center gap-3">
                <button
                  phx-click="capture_screenshot"
                  disabled={is_nil(@lens_state) || @loading}
                  class={[
                    "px-6 py-2 rounded-lg font-medium transition-colors",
                    if(is_nil(@lens_state) || @loading,
                      do: "bg-slate-300 text-slate-500 cursor-not-allowed",
                      else: "bg-green-600 text-white hover:bg-green-700"
                    )
                  ]}
                >
                  <%= if @loading do %>
                    Capturing...
                  <% else %>
                    Capture Screenshot
                  <% end %>
                </button>

                <%= if @screenshot do %>
                  <button
                    phx-click="clear_screenshot"
                    class="px-4 py-2 rounded-lg font-medium bg-slate-100 text-slate-700 hover:bg-slate-200"
                  >
                    Clear
                  </button>
                <% end %>
              </div>

              <%= if @screenshot_meta do %>
                <div class="mt-3 text-sm text-slate-600">
                  <span class="font-medium">Size:</span> <%= @screenshot_meta.size_kb %> KB |
                  <span class="font-medium">Captured:</span>
                  <%= Calendar.strftime(@screenshot_meta.captured_at, "%H:%M:%S") %>
                </div>
              <% end %>
            </div>

            <!-- Screenshot Display -->
            <div class="bg-white rounded-lg shadow p-4">
              <h2 class="text-lg font-semibold text-slate-800 mb-3">Screenshot Result</h2>
              <%= if @screenshot do %>
                <div class="border border-slate-200 rounded-lg overflow-hidden">
                  <img
                    src={"data:image/png;base64,#{@screenshot}"}
                    alt="Captured screenshot"
                    class="w-full h-auto"
                  />
                </div>
              <% else %>
                <div class="h-64 bg-slate-50 rounded-lg flex items-center justify-center">
                  <p class="text-slate-400 italic">
                    <%= if @lens_state do %>
                      Click "Capture Screenshot" to generate
                    <% else %>
                      Select a wireframe first
                    <% end %>
                  </p>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Info Box -->
        <div class="mt-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h3 class="font-semibold text-blue-800 mb-2">How it works</h3>
          <ol class="text-sm text-blue-700 space-y-1 list-decimal list-inside">
            <li>Select a wireframe from <code class="bg-blue-100 px-1 rounded">priv/wireframes/</code></li>
            <li>HTML is parsed into a DOM tree structure via <code class="bg-blue-100 px-1 rounded">HTMLParser</code></li>
            <li>DOM tree is converted to lens_state format</li>
            <li><code class="bg-blue-100 px-1 rounded">ScreenshotRenderer</code> converts lens_state to standalone HTML</li>
            <li>Puppeteer (headless Chrome) captures the rendered page as PNG</li>
            <li>Base64-encoded screenshot is displayed</li>
          </ol>
        </div>
      </div>
    </div>
    """
  end

  defp format_css(css_map) do
    css_map
    |> Enum.map(fn {selector, rules} -> "#{selector} {\n  #{rules}\n}" end)
    |> Enum.join("\n\n")
  end
end
