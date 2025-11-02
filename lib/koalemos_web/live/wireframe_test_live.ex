defmodule KoalemosWeb.WireframeTestLive do
  @moduledoc """
  Interactive wireframe test page (M4 Sprint 1).

  Provides a complete manual testing environment for the wireframe editor system:
  - Load and preview sample HTML files (simple, medium, complex)
  - File upload for custom HTML testing
  - Preview wireframe content in iframe
  - Foundation for testing WireframeEditor lens (future sprints)

  Route: /test/wireframe
  """
  use KoalemosWeb, :live_view
  require Logger

  @fixtures_path "test/fixtures"
  @available_samples [
    {"simple", "Simple Wireframe", "wireframe_simple.html"},
    {"medium", "Medium Wireframe", "wireframe_medium.html"},
    {"complex", "Complex Wireframe", "wireframe_complex.html"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Wireframe Test",
       current_html: nil,
       current_sample: nil,
       available_samples: @available_samples,
       loaded_html: nil,
       error_message: nil
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

        {:noreply,
         assign(socket,
           loaded_html: html_content,
           current_sample: sample_id,
           current_html: sample_name,
           error_message: nil
         )}

      {:error, reason} ->
        Logger.error("[WireframeTestLive] Failed to load sample #{sample_id}: #{inspect(reason)}")

        {:noreply,
         assign(socket,
           error_message: "Failed to load sample: #{reason}",
           loaded_html: nil
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
       error_message: nil
     )}
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
            <strong>How to test:</strong>
            Select a sample HTML file from the left panel to preview it in the iframe on the right. This environment will be expanded with WireframeEditor lens capabilities in future sprints.
          </p>
        </div>
      </div>
      <!-- Main Content: Control Panel + Preview -->
      <div class="flex-1 overflow-hidden flex">
        <!-- Control Panel (left side) -->
        <div class="w-1/3 border-r border-slate-300 bg-white flex flex-col p-4 overflow-auto">
          <div class="space-y-6">
            <!-- Sample Selection -->
            <div>
              <h2 class="text-lg font-semibold text-slate-800 mb-3">Sample HTML Files</h2>
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
            <!-- Future Features -->
            <div class="border-t border-slate-200 pt-4">
              <h2 class="text-sm font-semibold text-slate-500 mb-2">Coming in Future Sprints:</h2>
              <ul class="text-xs text-slate-500 space-y-1 list-disc list-inside">
                <li>WireframeEditor lens integration</li>
                <li>Real-time HTML editing</li>
                <li>DOM manipulation tools</li>
                <li>JavaScript handler testing</li>
                <li>CSS modification tools</li>
              </ul>
            </div>
          </div>
        </div>
        <!-- Preview Panel (right side) -->
        <div class="w-2/3 bg-slate-50 flex flex-col">
          <div class="bg-slate-700 px-4 py-2 border-b border-slate-600 flex items-center justify-between">
            <h2 class="text-sm font-medium text-white">HTML Preview (Iframe)</h2>
            <%= if @loaded_html do %>
              <div class="text-xs text-slate-300">
                Rendering in isolated iframe
              </div>
            <% end %>
          </div>
          <div class="flex-1 overflow-auto">
            <%= if @loaded_html do %>
              <!-- Iframe Preview -->
              <iframe
                id="wireframe-preview"
                srcdoc={@loaded_html}
                class="w-full h-full border-0"
                sandbox="allow-scripts"
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
      </div>
    </div>
    """
  end

  # Private Helpers

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
