defmodule KoalemosWeb.ScreenshotTestLive do
  @moduledoc """
  Interactive screenshot test page (M3 Sprint 3).

  Provides a complete manual testing environment for the screenshot system:
  - Full chat interface with AI (TestLens)
  - Iframe with sample HTML content
  - Screenshot capture triggered by saying "screenshot"
  - Real end-to-end test with JavaScript execution

  Route: /test/screenshot
  """
  use KoalemosWeb, :live_view
  require Logger

  alias KoalemosWeb.ChatPanel
  alias Koalemos.{EngineManager, Engine}
  alias Koalemos.Routines.TestChatRoutine
  alias Koalemos.Caches.ScreenshotCache

  @impl true
  def mount(_params, _session, socket) do
    routine_id = "screenshot-test-#{:erlang.unique_integer([:positive])}"

    socket =
      if connected?(socket) do
        # Subscribe to routine events
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}")
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine:#{routine_id}:messages")
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "screenshot:request:#{routine_id}")

        # Start routine with TestLens
        # Engine auto-calls initial_context/0 and merges with user context
        user_context = %{
          llm_provider: "anthropic",
          llm_model: "claude-haiku-4-5"
        }

        case EngineManager.start_routine(routine_id, TestChatRoutine, user_context) do
          {:ok, _pid} ->
            Logger.info("[ScreenshotTestLive] Started test routine #{routine_id}")

          {:error, reason} ->
            Logger.error(
              "[ScreenshotTestLive] Failed to start routine #{routine_id}: #{inspect(reason)}"
            )
        end

        socket
      else
        socket
      end

    {:ok,
     assign(socket,
       page_title: "Screenshot Test",
       routine_id: routine_id,
       status: :running,
       capture_count: 0,
       last_screenshot: nil,
       messages: []
     )}
  end

  @impl true
  def handle_event("screenshot_captured", screenshot_data, socket) do
    routine_id = socket.assigns.routine_id
    data = screenshot_data["data"]
    width = screenshot_data["width"]
    height = screenshot_data["height"]

    Logger.info(
      "[ScreenshotTestLive] Screenshot captured: #{width}x#{height}, #{byte_size(data)} bytes"
    )

    case ScreenshotCache.put(routine_id, data) do
      :ok ->
        Logger.info("[ScreenshotTestLive] Screenshot stored in cache")

        # Broadcast ready notification via PubSub
        Phoenix.PubSub.broadcast(
          Koalemos.PubSub,
          "screenshot:response:#{routine_id}",
          {:screenshot_ready, routine_id}
        )

        Logger.debug("[ScreenshotTestLive] Broadcast screenshot_ready notification")

        {:noreply,
         assign(socket,
           capture_count: socket.assigns.capture_count + 1,
           last_screenshot: %{
             width: width,
             height: height,
             size_kb: round(byte_size(data) / 1024),
             captured_at: DateTime.utc_now()
           }
         )}

      error ->
        Logger.error("[ScreenshotTestLive] Failed to store screenshot: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("screenshot_failed", error_data, socket) do
    error_msg = error_data["error"] || "Unknown error"
    Logger.error("[ScreenshotTestLive] Screenshot capture failed: #{error_msg}")

    {:noreply, socket}
  end

  @impl true
  def handle_info(:check_uploads, socket) do
    # Forward to nested UserInputComponent
    alias KoalemosWeb.UserInputComponent
    send_update(UserInputComponent, id: "chat-panel-input", check_uploads: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:clear_sent_feedback, component_id}, socket) do
    # Forward to nested UserInputComponent
    alias KoalemosWeb.UserInputComponent
    send_update(UserInputComponent, id: component_id, clear_sent_feedback: true)
    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:user_input_submitted,
         %{text: text, images: images, include_screenshot: include_screenshot}},
        socket
      ) do
    Logger.info(
      "[ScreenshotTestLive] User input submitted: text=#{text}, images=#{length(images)}, screenshot=#{include_screenshot}"
    )

    # Send user input to routine
    data = %{text: text, images: images, include_screenshot: include_screenshot}
    Engine.send_external_event(socket.assigns.routine_id, :user_input, data)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_messages, new_messages}, socket) do
    Logger.debug("[ScreenshotTestLive] Received #{length(new_messages)} new message(s)")

    updated_messages = socket.assigns.messages ++ new_messages
    {:noreply, assign(socket, messages: updated_messages)}
  end

  @impl true
  def handle_info({:screenshot_request, %{routine_id: requested_id}}, socket) do
    Logger.info("[ScreenshotTestLive] Screenshot request received for #{requested_id}")

    if socket.assigns.routine_id == requested_id do
      # Trigger screenshot capture via JavaScript hook on iframe
      {:noreply, push_event(socket, "trigger_screenshot_capture", %{})}
    else
      Logger.warning(
        "[ScreenshotTestLive] Screenshot request for wrong routine: #{requested_id} (current: #{socket.assigns.routine_id})"
      )

      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:routine_event, _event}, socket) do
    # Ignore other routine events
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-100">
      <!-- Header -->
      <div class="bg-white border-b border-slate-200 shadow-sm">
        <div class="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
          <div>
            <h1 class="text-xl font-semibold text-slate-800">Screenshot Integration Test</h1>
            <p class="text-sm text-slate-600 mt-1">
              M3 Sprint 3: Full end-to-end screenshot testing with chat
            </p>
          </div>
          <div class="flex items-center gap-4">
            <div class="text-sm text-slate-600">
              <span class="font-medium text-slate-700">Captures:</span>
              <span class="font-mono">{@capture_count}</span>
            </div>
            <%= if @last_screenshot do %>
              <div class="text-sm text-green-600">
                <span class="font-medium">Last:</span>
                <span class="font-mono">
                  {@last_screenshot.width}x{@last_screenshot.height} ({@last_screenshot.size_kb} KB)
                </span>
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
            Check the "screenshot" checkbox in the input panel, then send your message. The AI will capture the content on the right and include it in the conversation.
          </p>
        </div>
      </div>
      <!-- Main Content: Chat + Iframe -->
      <div class="flex-1 overflow-hidden flex">
        <!-- Chat Panel (left side) -->
        <div class="w-1/2 border-r border-slate-300 bg-white flex flex-col">
          <div class="flex-1 overflow-hidden">
            <.live_component
              module={ChatPanel}
              id="chat-panel"
              routine_id={@routine_id}
              messages={@messages}
              mock_responses={false}
              current_step={nil}
              show_screenshot_checkbox={true}
            />
          </div>
        </div>
        <!-- Iframe Target (right side) -->
        <div class="w-1/2 bg-slate-50 flex flex-col">
          <div class="bg-slate-700 px-4 py-2 border-b border-slate-600">
            <h2 class="text-sm font-medium text-white">Screenshot Target (Iframe)</h2>
          </div>
          <div class="flex-1 p-4 overflow-auto">
            <!-- ScreenshotCapture hook wraps the iframe content -->
            <div
              id="screenshot-target"
              phx-hook="ScreenshotCapture"
              class="h-full bg-white rounded-lg shadow-lg p-8 overflow-auto"
            >
              <div class="space-y-6">
                <!-- Sample Content -->
                <div>
                  <h1 class="text-4xl font-bold text-slate-900 mb-2">Sample Wireframe</h1>
                  <p class="text-lg text-slate-600">
                    This is the content that will be captured in screenshots
                  </p>
                </div>
                <!-- Feature Cards -->
                <div class="grid grid-cols-2 gap-4">
                  <div class="bg-blue-50 border-2 border-blue-200 rounded-lg p-4">
                    <div class="text-blue-600 text-2xl mb-2">🎨</div>
                    <h3 class="font-semibold text-blue-900 mb-1">Design</h3>
                    <p class="text-sm text-blue-700">Beautiful user interfaces</p>
                  </div>
                  <div class="bg-green-50 border-2 border-green-200 rounded-lg p-4">
                    <div class="text-green-600 text-2xl mb-2">⚡</div>
                    <h3 class="font-semibold text-green-900 mb-1">Performance</h3>
                    <p class="text-sm text-green-700">Lightning fast responses</p>
                  </div>
                  <div class="bg-purple-50 border-2 border-purple-200 rounded-lg p-4">
                    <div class="text-purple-600 text-2xl mb-2">🔒</div>
                    <h3 class="font-semibold text-purple-900 mb-1">Security</h3>
                    <p class="text-sm text-purple-700">Enterprise-grade protection</p>
                  </div>
                  <div class="bg-orange-50 border-2 border-orange-200 rounded-lg p-4">
                    <div class="text-orange-600 text-2xl mb-2">📱</div>
                    <h3 class="font-semibold text-orange-900 mb-1">Responsive</h3>
                    <p class="text-sm text-orange-700">Works on any device</p>
                  </div>
                </div>
                <!-- Sample Form -->
                <div class="bg-slate-50 border border-slate-200 rounded-lg p-6">
                  <h2 class="text-xl font-semibold text-slate-800 mb-4">Contact Form</h2>
                  <div class="space-y-3">
                    <div>
                      <label class="block text-sm font-medium text-slate-700 mb-1">Name</label>
                      <input
                        type="text"
                        placeholder="Enter your name"
                        class="w-full px-3 py-2 border border-slate-300 rounded focus:ring-2 focus:ring-blue-500"
                      />
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-slate-700 mb-1">Email</label>
                      <input
                        type="email"
                        placeholder="you@example.com"
                        class="w-full px-3 py-2 border border-slate-300 rounded focus:ring-2 focus:ring-blue-500"
                      />
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-slate-700 mb-1">Message</label>
                      <textarea
                        placeholder="Your message..."
                        rows="3"
                        class="w-full px-3 py-2 border border-slate-300 rounded focus:ring-2 focus:ring-blue-500"
                      >
                      </textarea>
                    </div>
                    <button class="w-full px-4 py-2 bg-blue-600 text-white font-medium rounded hover:bg-blue-700 transition-colors">
                      Send Message
                    </button>
                  </div>
                </div>
                <!-- Sample Buttons -->
                <div class="flex gap-3 flex-wrap">
                  <button class="px-6 py-2 bg-slate-800 text-white rounded-lg hover:bg-slate-900">
                    Primary Action
                  </button>
                  <button class="px-6 py-2 bg-white border-2 border-slate-800 text-slate-800 rounded-lg hover:bg-slate-50">
                    Secondary Action
                  </button>
                  <button class="px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700">
                    Delete
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
