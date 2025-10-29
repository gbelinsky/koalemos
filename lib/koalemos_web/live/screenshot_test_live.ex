defmodule KoalemosWeb.ScreenshotTestLive do
  @moduledoc """
  Test page for screenshot capture functionality (M3 Sprint 2).

  This page demonstrates the ScreenshotCapture JavaScript hook
  and provides a manual testing interface for screenshot functionality.

  Features:
  - Manual screenshot capture via button click
  - Sample HTML content for testing
  - Display of last screenshot metadata
  - ScreenshotCache integration

  Route: /test/screenshot
  """
  use KoalemosWeb, :live_view
  require Logger

  alias Koalemos.Caches.ScreenshotCache

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Screenshot Test",
       routine_id: "screenshot-test-#{:erlang.unique_integer([:positive])}",
       last_screenshot: nil,
       capture_count: 0,
       last_error: nil
     )}
  end

  @impl true
  def handle_event("capture_screenshot", _params, socket) do
    Logger.info("[ScreenshotTestLive] Capture button clicked")

    # Send event to JavaScript hook to trigger capture
    {:noreply, push_event(socket, "trigger_screenshot_capture", %{})}
  end

  @impl true
  def handle_event("screenshot_captured", screenshot_data, socket) do
    routine_id = socket.assigns.routine_id
    data = screenshot_data["data"]
    width = screenshot_data["width"]
    height = screenshot_data["height"]
    timestamp = screenshot_data["timestamp"]

    Logger.info(
      "[ScreenshotTestLive] Screenshot received: #{width}x#{height}, #{byte_size(data)} bytes (base64)"
    )

    # Store in ScreenshotCache
    case ScreenshotCache.put(routine_id, data) do
      :ok ->
        Logger.info("[ScreenshotTestLive] Screenshot stored in cache for #{routine_id}")

        # Update UI state
        {:noreply,
         assign(socket,
           last_screenshot: %{
             width: width,
             height: height,
             size_kb: round(byte_size(data) / 1024),
             timestamp: timestamp,
             captured_at: DateTime.utc_now()
           },
           capture_count: socket.assigns.capture_count + 1,
           last_error: nil
         )}

      error ->
        Logger.error("[ScreenshotTestLive] Failed to store screenshot: #{inspect(error)}")
        {:noreply, assign(socket, last_error: "Failed to store screenshot")}
    end
  end

  @impl true
  def handle_event("screenshot_failed", error_data, socket) do
    error_msg = error_data["error"] || "Unknown error"
    Logger.error("[ScreenshotTestLive] Screenshot capture failed: #{error_msg}")

    {:noreply, assign(socket, last_error: error_msg)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <div class="bg-white border-b border-gray-200 shadow-sm">
        <div class="max-w-6xl mx-auto px-4 py-4">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">Screenshot Test</h1>
              <p class="text-sm text-gray-600 mt-1">
                M3 Sprint 2: Screenshot Capture Testing
              </p>
            </div>
            <a
              href="/"
              class="text-sm text-blue-600 hover:text-blue-800 font-medium transition-colors"
            >
              ← Back to Home
            </a>
          </div>
        </div>
      </div>
      <!-- Main Content -->
      <div class="max-w-6xl mx-auto px-4 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Screenshot Target Area -->
          <div class="lg:col-span-2 space-y-6">
            <!-- Instructions -->
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <h2 class="text-lg font-semibold text-blue-900 mb-2">How to Test</h2>
              <ol class="list-decimal list-inside space-y-1 text-sm text-blue-800">
                <li>Click the "Capture Screenshot" button below</li>
                <li>Check the browser console for capture logs</li>
                <li>View screenshot metadata in the status panel →</li>
                <li>Verify screenshot stored in cache (check IEx)</li>
              </ol>
            </div>
            <!-- Capture Target (with phx-hook) -->
            <div
              id="capture-target"
              phx-hook="ScreenshotCapture"
              class="bg-white border-2 border-gray-300 rounded-lg p-8 shadow-sm"
            >
              <div class="space-y-6">
                <!-- Heading Examples -->
                <div>
                  <h1 class="text-3xl font-bold text-gray-900">Sample Heading 1</h1>
                  <h2 class="text-2xl font-semibold text-gray-800 mt-2">Sample Heading 2</h2>
                  <h3 class="text-xl font-medium text-gray-700 mt-2">Sample Heading 3</h3>
                </div>
                <!-- Colored Boxes -->
                <div class="grid grid-cols-3 gap-4">
                  <div class="bg-red-100 border border-red-300 rounded p-4 text-center">
                    <p class="text-red-800 font-semibold">Red Box</p>
                  </div>
                  <div class="bg-green-100 border border-green-300 rounded p-4 text-center">
                    <p class="text-green-800 font-semibold">Green Box</p>
                  </div>
                  <div class="bg-blue-100 border border-blue-300 rounded p-4 text-center">
                    <p class="text-blue-800 font-semibold">Blue Box</p>
                  </div>
                </div>
                <!-- Sample Text -->
                <div class="prose max-w-none">
                  <p class="text-gray-700">
                    This is sample paragraph text with <strong>bold</strong>
                    and <em>italic</em>
                    formatting. The screenshot capture will include all of this content.
                  </p>
                  <ul class="list-disc list-inside text-gray-600">
                    <li>Bullet point one</li>
                    <li>Bullet point two</li>
                    <li>Bullet point three</li>
                  </ul>
                </div>
                <!-- Sample Buttons -->
                <div class="flex gap-3">
                  <button class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600">
                    Sample Button
                  </button>
                  <button class="px-4 py-2 bg-gray-200 text-gray-800 rounded hover:bg-gray-300">
                    Another Button
                  </button>
                </div>
              </div>
            </div>
            <!-- Capture Button -->
            <div class="flex justify-center">
              <button
                phx-click="capture_screenshot"
                class="px-8 py-3 bg-green-600 text-white font-semibold rounded-lg shadow-md hover:bg-green-700 transition-colors"
              >
                📸 Capture Screenshot
              </button>
            </div>
          </div>
          <!-- Status Panel -->
          <div class="space-y-6">
            <!-- Stats -->
            <div class="bg-white border border-gray-200 rounded-lg p-4 shadow-sm">
              <h2 class="text-lg font-semibold text-gray-900 mb-3">Status</h2>
              <div class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <span class="text-gray-600">Captures:</span>
                  <span class="font-semibold text-gray-900"><%= @capture_count %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-600">Routine ID:</span>
                  <span class="font-mono text-xs text-gray-700"><%= @routine_id %></span>
                </div>
              </div>
            </div>
            <!-- Last Screenshot Info -->
            <%= if @last_screenshot do %>
              <div class="bg-green-50 border border-green-200 rounded-lg p-4 shadow-sm">
                <h2 class="text-lg font-semibold text-green-900 mb-3">Last Screenshot</h2>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-green-700">Dimensions:</span>
                    <span class="font-semibold text-green-900">
                      <%= @last_screenshot.width %>x<%= @last_screenshot.height %>
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-green-700">Size:</span>
                    <span class="font-semibold text-green-900">
                      <%= @last_screenshot.size_kb %> KB
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-green-700">Captured:</span>
                    <span class="font-semibold text-green-900">
                      <%= Calendar.strftime(@last_screenshot.captured_at, "%H:%M:%S") %>
                    </span>
                  </div>
                </div>
              </div>
            <% end %>
            <!-- Error Display -->
            <%= if @last_error do %>
              <div class="bg-red-50 border border-red-200 rounded-lg p-4 shadow-sm">
                <h2 class="text-lg font-semibold text-red-900 mb-2">Error</h2>
                <p class="text-sm text-red-700"><%= @last_error %></p>
              </div>
            <% end %>
            <!-- IEx Verification -->
            <div class="bg-gray-100 border border-gray-300 rounded-lg p-4">
              <h2 class="text-sm font-semibold text-gray-800 mb-2">Verify in IEx</h2>
              <pre class="text-xs text-gray-700 font-mono bg-white p-2 rounded border border-gray-200 overflow-x-auto"><code>alias Koalemos.Caches.ScreenshotCache
                ScreenshotCache.get("<%= @routine_id %>")</code></pre>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
