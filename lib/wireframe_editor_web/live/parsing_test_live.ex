defmodule WireframeEditorWeb.ParsingTestLive do
  use WireframeEditorWeb, :live_view
  alias WireframeEditorWeb.Integrations.ParsingIntegration

  @impl true
  def mount(_params, _session, socket) do
    routine_id = "parsing-test-#{:erlang.unique_integer([:positive])}"

    # Sample HTML for demo
    sample_html = """
    <div class="counter-app">
      <h1>Counter Demo</h1>
      <button id="increment">Increment</button>
      <button id="decrement">Decrement</button>
      <div>Count: <span id="display">0</span></div>

      <style>
        .counter-app { padding: 20px; }
        button { margin: 5px; }
      </style>

      <script>
        window.count = 0;

        window.updateDisplay = function() {
          document.getElementById('display').textContent = window.count;
        };

        document.getElementById('increment').addEventListener('click', function() {
          window.count++;
          window.updateDisplay();
        });

        document.getElementById('decrement').addEventListener('click', function() {
          window.count--;
          window.updateDisplay();
        });
      </script>
    </div>
    """

    socket =
      socket
      |> assign(:routine_id, routine_id)
      |> assign(:html_input, sample_html)
      |> assign(:wireframe, nil)
      |> assign(:dom_cache, nil)
      |> assign(:var_cache, nil)
      |> assign(:console_cache, [])
      |> assign(:error, nil)
      |> allow_upload(:html_file,
        accept: ~w(.html .htm),
        max_entries: 1,
        max_file_size: 1_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("parse", %{"html" => html_input}, socket) do
    case ParsingIntegration.parse_wireframe(html_input, socket.assigns.routine_id) do
      {:ok, wireframe} ->
        # Display parsed data directly from wireframe result
        socket =
          socket
          |> assign(:wireframe, wireframe)
          |> assign(:dom_cache, wireframe.dom_tree)
          |> assign(:var_cache, wireframe.javascript.variables)
          |> assign(:console_cache, [])
          |> assign(:error, nil)

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:error, "Parse failed: #{inspect(reason)}")
          |> assign(:wireframe, nil)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear", _params, socket) do
    socket =
      socket
      |> assign(:wireframe, nil)
      |> assign(:dom_cache, nil)
      |> assign(:var_cache, nil)
      |> assign(:console_cache, [])
      |> assign(:error, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("load-file", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :html_file, fn %{path: path}, _entry ->
        content = File.read!(path)
        {:ok, content}
      end)

    case uploaded_files do
      [content | _] ->
        {:noreply, assign(socket, :html_input, content)}

      [] ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-8">
      <div class="mb-4">
        <a href="/test" class="text-blue-600 hover:text-blue-800 transition-colors">
          ← Back to Test Pages
        </a>
      </div>

      <h1 class="text-3xl font-bold mb-6">M3 Parsing Integration Test</h1>

      <div class="mb-4 p-4 bg-blue-50 border border-blue-200 rounded">
        <p class="text-sm text-blue-800">
          <strong>What this demonstrates:</strong> HTML/JavaScript parsing pipeline (Sprint 6 & 7).
          Parses HTML wireframes, extracts DOM structure, JavaScript variables, functions, and event handlers.
          Stores initial state in caches for runtime tracking.
        </p>
      </div>
      
    <!-- Input Section -->
      <div class="mb-8">
        <h2 class="text-2xl font-semibold mb-4">Input HTML</h2>
        
    <!-- File Upload -->
        <div class="mb-4">
          <form phx-change="validate" phx-submit="load-file" class="flex gap-2 items-end">
            <div class="flex-1">
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Load HTML File
              </label>
              <.live_file_input upload={@uploads.html_file} class="block w-full text-sm" />
            </div>
            <button
              type="submit"
              class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              Load File
            </button>
          </form>
        </div>
        
    <!-- Text Area -->
        <form phx-submit="parse">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Or Paste HTML Here
            </label>
            <textarea
              name="html"
              class="w-full h-64 p-3 border rounded font-mono text-sm"
              id="html-input"
            ><%= @html_input %></textarea>
          </div>
          
    <!-- Action Buttons -->
          <div class="mt-4 flex gap-2">
            <button
              type="submit"
              class="px-6 py-2 bg-green-500 text-white rounded hover:bg-green-600 font-semibold"
            >
              Parse Wireframe
            </button>
            <button
              type="button"
              phx-click="clear"
              class="px-6 py-2 bg-gray-500 text-white rounded hover:bg-gray-600"
            >
              Clear Results
            </button>
          </div>
        </form>

        <%= if @error do %>
          <div class="mt-4 p-4 bg-red-50 border border-red-200 rounded">
            <p class="text-red-800">{@error}</p>
          </div>
        <% end %>
      </div>
      
    <!-- Results Section -->
      <%= if @wireframe do %>
        <div class="border-t pt-8">
          <h2 class="text-2xl font-semibold mb-4">Parsing Results</h2>
          
    <!-- Parse Statistics -->
          <div class="mb-6 p-4 bg-green-50 border border-green-200 rounded">
            <h3 class="font-semibold mb-2">Parse Statistics</h3>
            <div class="grid grid-cols-2 gap-4 text-sm">
              <!-- Scripts Column -->
              <div>
                <div class="font-semibold text-gray-700 mb-1">JavaScript</div>
                <ul class="space-y-1 ml-2">
                  <li>📜 Inline Scripts: {@wireframe.parse_results.scripts_parsed}</li>
                  <li>
                    🔗 External Scripts: {Enum.count(@wireframe.scripts, &(&1.type == :external))}
                  </li>
                  <li>📦 Variables: {map_size(@wireframe.javascript.variables)}</li>
                  <li>⚙️ Functions: {map_size(@wireframe.javascript.functions)}</li>
                  <li>🖱️ Handlers: {map_size(@wireframe.javascript.handlers)}</li>
                  <li>
                    🚀 Init Scripts: {length(
                      @wireframe.javascript.init_scripts
                      |> Enum.filter(&(&1 != ""))
                    )}
                  </li>
                  <%= if @wireframe.parse_results.scripts_failed > 0 do %>
                    <li class="text-red-600">
                      ❌ Parse Errors: {@wireframe.parse_results.scripts_failed}
                    </li>
                  <% end %>
                </ul>
              </div>
              
    <!-- Styles Column -->
              <div>
                <div class="font-semibold text-gray-700 mb-1">CSS</div>
                <ul class="space-y-1 ml-2">
                  <li>🎨 Inline Styles: {@wireframe.parse_results.styles_parsed}</li>
                  <li>
                    🔗 External Stylesheets: {Enum.count(@wireframe.styles, &(&1.type == :external))}
                  </li>
                  <li>📐 CSS Rules: {length(@wireframe.css_rules)}</li>
                  <%= if @wireframe.parse_results.styles_failed > 0 do %>
                    <li class="text-red-600">
                      ❌ Parse Errors: {@wireframe.parse_results.styles_failed}
                    </li>
                  <% end %>
                </ul>
              </div>
            </div>

            <%= if length(@wireframe.parse_results.errors) > 0 do %>
              <div class="mt-3 pt-3 border-t border-green-300">
                <div class="text-sm font-semibold text-red-600">Errors:</div>
                <ul class="text-xs text-red-600 mt-1 ml-4 space-y-1">
                  <%= for error <- @wireframe.parse_results.errors do %>
                    <li>• {error}</li>
                  <% end %>
                </ul>
              </div>
            <% end %>
          </div>
          
    <!-- Grid Layout for Results -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- DOM Tree -->
            <div class="border rounded p-4">
              <h3 class="font-semibold text-lg mb-3">DOM Tree</h3>
              <div class="bg-gray-50 p-3 rounded overflow-auto max-h-96 text-sm font-mono">
                <pre><%= render_dom_tree(@wireframe.dom_tree, 0) %></pre>
              </div>
            </div>
            
    <!-- JavaScript Variables -->
            <div class="border rounded p-4">
              <h3 class="font-semibold text-lg mb-3">JavaScript Variables</h3>
              <%= if map_size(@wireframe.javascript.variables) > 0 do %>
                <div class="overflow-auto max-h-96">
                  <table class="w-full text-sm">
                    <thead class="bg-gray-100">
                      <tr>
                        <th class="text-left p-2 border-b">Variable</th>
                        <th class="text-left p-2 border-b">Value</th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for {name, value} <- @wireframe.javascript.variables do %>
                        <tr class="border-b">
                          <td class="p-2 font-mono">{name}</td>
                          <td class="p-2 font-mono">{inspect(value)}</td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% else %>
                <p class="text-gray-500 text-sm italic">No variables found</p>
              <% end %>
            </div>
            
    <!-- Functions -->
            <div class="border rounded p-4">
              <h3 class="font-semibold text-lg mb-3">Functions</h3>
              <%= if map_size(@wireframe.javascript.functions) > 0 do %>
                <div class="space-y-3 overflow-auto max-h-96">
                  <%= for {name, code} <- @wireframe.javascript.functions do %>
                    <div class="bg-gray-50 p-2 rounded">
                      <div class="font-mono font-semibold text-sm mb-1">{name}</div>
                      <pre class="text-xs bg-white p-2 rounded overflow-x-auto"><%= code %></pre>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <p class="text-gray-500 text-sm italic">No functions found</p>
              <% end %>
            </div>
            
    <!-- Event Handlers -->
            <div class="border rounded p-4">
              <h3 class="font-semibold text-lg mb-3">Event Handlers</h3>
              <%= if map_size(@wireframe.javascript.handlers) > 0 do %>
                <div class="space-y-3 overflow-auto max-h-96">
                  <%= for {element_id, events} <- @wireframe.javascript.handlers do %>
                    <div class="bg-gray-50 p-3 rounded">
                      <div class="font-semibold text-sm mb-2">
                        Element: <span class="font-mono text-blue-600">#{element_id}</span>
                      </div>
                      <%= for {event_type, handler} <- events do %>
                        <div class="ml-4 mb-2">
                          <div class="text-xs text-gray-600">
                            on{event_type}({Enum.join(handler.params, ", ")})
                          </div>
                          <pre class="text-xs bg-white p-2 rounded mt-1 overflow-x-auto"><%= handler.body %></pre>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <p class="text-gray-500 text-sm italic">No event handlers found</p>
              <% end %>
            </div>
            
    <!-- CSS Rules -->
            <div class="border rounded p-4">
              <h3 class="font-semibold text-lg mb-3">CSS Rules</h3>
              <%= if length(@wireframe.css_rules) > 0 do %>
                <div class="space-y-2 overflow-auto max-h-96">
                  <%= for rule <- @wireframe.css_rules do %>
                    <div class="bg-gray-50 p-2 rounded">
                      <div class="text-sm font-semibold text-blue-700 mb-1">
                        {rule.selector}
                      </div>
                      <div class="ml-4 text-xs space-y-1">
                        <%= for {property, value} <- rule.declarations do %>
                          <div class="bg-white p-1 rounded font-mono">
                            <span class="text-purple-600"><%= property %></span>: <span class="text-gray-700"><%= value %></span>;
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <p class="text-gray-500 text-sm italic">No CSS rules found</p>
              <% end %>
            </div>
            
    <!-- Init Scripts -->
            <div class="border rounded p-4">
              <h3 class="font-semibold text-lg mb-3">Init Scripts</h3>
              <% non_empty_init_scripts = Enum.filter(@wireframe.javascript.init_scripts, &(&1 != "")) %>
              <%= if length(non_empty_init_scripts) > 0 do %>
                <div class="space-y-3 overflow-auto max-h-96">
                  <%= for {script, idx} <- Enum.with_index(non_empty_init_scripts) do %>
                    <div class="bg-gray-50 p-2 rounded">
                      <div class="text-xs font-semibold text-gray-600 mb-1">
                        Init Script #{idx + 1}
                      </div>
                      <pre class="text-xs bg-white p-2 rounded overflow-x-auto"><%= script %></pre>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <p class="text-gray-500 text-sm italic">
                  No init scripts (all code was extracted as variables/functions/handlers)
                </p>
              <% end %>
            </div>
            
    <!-- External Resources -->
            <div class="border rounded p-4">
              <h3 class="font-semibold text-lg mb-3">External Resources</h3>
              <% external_scripts = Enum.filter(@wireframe.scripts, &(&1.type == :external)) %>
              <% external_styles = Enum.filter(@wireframe.styles, &(&1.type == :external)) %>
              <%= if length(external_scripts) > 0 or length(external_styles) > 0 do %>
                <div class="space-y-3 overflow-auto max-h-96">
                  <%= if length(external_scripts) > 0 do %>
                    <div>
                      <div class="text-sm font-semibold text-blue-700 mb-2">📜 External Scripts</div>
                      <%= for script <- external_scripts do %>
                        <div class="bg-blue-50 p-2 rounded mb-2 text-xs font-mono">
                          <div class="font-semibold">src: {script.src}</div>
                          <%= if map_size(script.attributes) > 1 do %>
                            <div class="text-gray-600 mt-1">
                              Attributes: {inspect(Map.delete(script.attributes, "src"))}
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                  <%= if length(external_styles) > 0 do %>
                    <div>
                      <div class="text-sm font-semibold text-purple-700 mb-2">
                        🎨 External Stylesheets
                      </div>
                      <%= for style <- external_styles do %>
                        <div class="bg-purple-50 p-2 rounded mb-2 text-xs font-mono">
                          <div class="font-semibold">href: {style.src}</div>
                          <%= if map_size(style.attributes) > 2 do %>
                            <div class="text-gray-600 mt-1">
                              Attributes: {inspect(
                                Map.delete(Map.delete(style.attributes, "href"), "rel")
                              )}
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <p class="text-gray-500 text-sm italic">
                  No external resources (not fetched, just tracked)
                </p>
              <% end %>
            </div>
            
    <!-- Metadata -->
            <div class="border rounded p-4">
              <h3 class="font-semibold text-lg mb-3">Metadata</h3>
              <div class="text-sm space-y-2">
                <%= if @wireframe.metadata.title do %>
                  <div>
                    <span class="font-semibold">Title:</span>
                    <span class="ml-2">{@wireframe.metadata.title}</span>
                  </div>
                <% end %>
                <%= if length(@wireframe.metadata.meta_tags) > 0 do %>
                  <div>
                    <span class="font-semibold">Meta Tags:</span>
                    <div class="ml-4 mt-1 space-y-1">
                      <%= for meta <- @wireframe.metadata.meta_tags do %>
                        <div class="text-xs font-mono bg-gray-50 p-1 rounded">
                          {inspect(meta)}
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
                <%= if !@wireframe.metadata.title && length(@wireframe.metadata.meta_tags) == 0 do %>
                  <p class="text-gray-500 italic">No metadata found</p>
                <% end %>
              </div>
            </div>
          </div>
          
    <!-- Cache Status -->
          <div class="mt-8 border-t pt-6">
            <h2 class="text-2xl font-semibold mb-4">Cache Status (Runtime State Tracking)</h2>
            <p class="text-sm text-gray-600 mb-4">
              These caches store initial state for wireframe execution. Updated during runtime as JavaScript executes.
            </p>

            <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <!-- DOMStateCache -->
              <div class="border rounded p-4 bg-purple-50">
                <h3 class="font-semibold text-lg mb-3">DOMStateCache</h3>
                <p class="text-xs text-gray-600 mb-3">
                  Stores live DOM structure for runtime tracking
                </p>
                <%= if @dom_cache do %>
                  <div class="text-sm space-y-2">
                    <div>
                      <span class="font-semibold">Change Type:</span>
                      <span class="ml-2">{@dom_cache.change_type}</span>
                    </div>
                    <div>
                      <span class="font-semibold">Cached At:</span>
                      <span class="ml-2">{@dom_cache.cached_at}</span>
                    </div>
                    <div>
                      <span class="font-semibold">Root Tag:</span>
                      <span class="ml-2 font-mono">{@dom_cache.live_dom_tree.tag}</span>
                    </div>
                  </div>
                <% else %>
                  <p class="text-gray-500 text-sm italic">No DOM cached</p>
                <% end %>
              </div>
              
    <!-- VariableStateCache -->
              <div class="border rounded p-4 bg-yellow-50">
                <h3 class="font-semibold text-lg mb-3">VariableStateCache</h3>
                <p class="text-xs text-gray-600 mb-3">Stores runtime variable values (window.*)</p>
                <%= if @var_cache do %>
                  <div class="text-sm">
                    <div class="font-semibold mb-2">Cached Variables:</div>
                    <div class="bg-white p-2 rounded font-mono text-xs">
                      {inspect(@var_cache, pretty: true)}
                    </div>
                  </div>
                <% else %>
                  <p class="text-gray-500 text-sm italic">No variables cached</p>
                <% end %>
              </div>
              
    <!-- ConsoleCache -->
              <div class="border rounded p-4 bg-green-50">
                <h3 class="font-semibold text-lg mb-3">ConsoleCache</h3>
                <p class="text-xs text-gray-600 mb-3">
                  Stores console output during execution (rate-limited)
                </p>
                <%= if @console_cache && length(@console_cache) > 0 do %>
                  <div class="text-sm">
                    <div class="font-semibold mb-2">Messages: {length(@console_cache)}</div>
                    <div class="bg-white p-2 rounded text-xs max-h-48 overflow-auto">
                      <%= for msg <- Enum.take(@console_cache, 10) do %>
                        <div class="font-mono mb-1 text-gray-700">
                          [{msg.level}] {msg.message}
                        </div>
                      <% end %>
                      <%= if length(@console_cache) > 10 do %>
                        <div class="text-gray-500 italic mt-2">
                          ... and {length(@console_cache) - 10} more
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% else %>
                  <p class="text-gray-500 text-sm italic">
                    No console messages (populated during execution)
                  </p>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper to render DOM tree recursively as plain string
  defp render_dom_tree(nil, _depth), do: ""

  defp render_dom_tree(node, depth) when is_map(node) do
    indent = String.duplicate("  ", depth)
    tag = node.tag || "unknown"
    id_str = if node.id, do: " id=\"#{node.id}\"", else: ""

    class_str =
      if length(node.classes || []) > 0,
        do: " class=\"#{Enum.join(node.classes, " ")}\"",
        else: ""

    children_html =
      if node.children && length(node.children) > 0 do
        Enum.map(node.children, &render_dom_tree(&1, depth + 1))
        |> Enum.join("")
      else
        ""
      end

    content_str = if node.content && node.content != "", do: " → #{node.content}", else: ""

    "#{indent}<#{tag}#{id_str}#{class_str}>#{content_str}\n#{children_html}"
  end
end
