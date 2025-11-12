defmodule Koalemos.Lenses.Helpers.ScreenshotCapture do
  @moduledoc """
  Helper for capturing screenshots from LiveView pages via JavaScript hook.

  ## Overview

  This module provides a reusable screenshot capture system for lenses that need
  to include visual context from the current page state. It's particularly useful
  for lenses that work with visual interfaces (e.g., WireframeEditor).

  ## Architecture

  The screenshot system involves multiple components working together:

  ### 1. JavaScript Hook: `ScreenshotCapture`

  **Location:** `assets/js/wireframe_hooks.js`

  **Purpose:** Captures DOM elements as PNG images using html2canvas

  **Lifecycle:**
  - `mounted()`: Sets up event listener for "trigger_screenshot_capture"
  - On trigger: Uses html2canvas to render DOM element to canvas
  - Converts canvas to Base64 PNG string
  - Sends result back via `pushEvent("screenshot_captured", {data: base64})`

  **Usage in Template:**
  ```heex
  <div id="screenshot-target" phx-hook="ScreenshotCapture">
    <!-- Content to capture -->
  </div>
  ```

  ### 2. PubSub Messages (Elixir ↔ LiveView)

  **Request Message:**
  - **Topic:** `"screenshot:request:\#{routine_id}"`
  - **Message:** `{:screenshot_request, %{routine_id: string, timestamp: DateTime}}`
  - **Direction:** Lens (Engine process) → LiveView
  - **Purpose:** Trigger screenshot capture in the browser

  **Notification Message:**
  - **Topic:** N/A (direct send to Engine process)
  - **Message:** `{:screenshot_ready, routine_id}`
  - **Direction:** LiveView → Lens (Engine process)
  - **Purpose:** Notify lens that screenshot is ready in cache

  ### 3. WebSocket Events (LiveView ↔ JavaScript)

  **Trigger Event:**
  - **Event:** `"trigger_screenshot_capture"`
  - **Payload:** `%{}` (empty)
  - **Direction:** LiveView → JavaScript hook
  - **Sent via:** `push_event(socket, "trigger_screenshot_capture", %{})`

  **Result Event:**
  - **Event:** `"screenshot_captured"`
  - **Payload:** `%{data: base64_png_string}`
  - **Direction:** JavaScript hook → LiveView
  - **Sent via:** `pushEvent("screenshot_captured", {data: base64})`

  **Error Event:**
  - **Event:** `"screenshot_failed"`
  - **Payload:** `%{error: error_message}`
  - **Direction:** JavaScript hook → LiveView
  - **Sent via:** `pushEvent("screenshot_failed", {error: message})`

  ### 4. ScreenshotCache

  **Module:** `Koalemos.Caches.ScreenshotCache`

  **Purpose:** In-memory storage for captured screenshots

  **Operations:**
  - `put(routine_id, base64_data)` - Store screenshot
  - `get(routine_id)` - Retrieve screenshot
  - `clear(routine_id)` - Remove screenshot

  ### 5. LiveView Integration

  **Required in LiveView:**
  ```elixir
  # In mount/3 or handle_params/3:
  Phoenix.PubSub.subscribe(Koalemos.PubSub, "screenshot:request:\#{routine_id}")

  # Handle screenshot request from lens:
  def handle_info({:screenshot_request, %{routine_id: requested_id}}, socket) do
    if socket.assigns.routine_id == requested_id do
      {:noreply, push_event(socket, "trigger_screenshot_capture", %{})}
    else
      {:noreply, socket}
    end
  end

  # Handle captured screenshot from JavaScript:
  def handle_event("screenshot_captured", %{"data" => data}, socket) do
    routine_id = socket.assigns.routine_id
    :ok = ScreenshotCache.put(routine_id, data)

    # Notify waiting Engine process
    case EngineManager.get_routine(routine_id) do
      {:ok, routine_info} ->
        send(routine_info.pid, {:screenshot_ready, routine_id})
      {:error, _} ->
        :ok
    end

    {:noreply, socket}
  end
  ```

  ## Complete Flow

  ```
  1. Tool sets :request_screenshot flag in lens_state
     ↓
  2. Lens provide_context() checks flag
     ↓
  3. Lens calls ScreenshotCapture.capture(routine_id)
     ↓
  4. Helper broadcasts PubSub message (screenshot:request:routine_id)
     ↓
  5. LiveView receives PubSub message
     ↓
  6. LiveView sends WebSocket event (trigger_screenshot_capture)
     ↓
  7. JavaScript hook receives event
     ↓
  8. Hook uses html2canvas to capture DOM → canvas → Base64 PNG
     ↓
  9. Hook sends WebSocket event (screenshot_captured with data)
     ↓
  10. LiveView receives event and stores in ScreenshotCache
      ↓
  11. LiveView sends notification to Engine process ({:screenshot_ready, routine_id})
      ↓
  12. Helper's receive block unblocks
      ↓
  13. Helper retrieves from ScreenshotCache
      ↓
  14. Helper returns formatted image content block
      ↓
  15. Lens includes screenshot in context blocks
      ↓
  16. AI receives screenshot with next message
  ```

  ## Usage in Lenses

  ```elixir
  def provide_context(state) do
    text_blocks = [%{type: "text", text: "Base context"}]

    screenshot_blocks =
      if Map.get(Map.get(state.context, :lens_state, %{}), :request_screenshot, false) do
        routine_id = state.routine_id

        case Koalemos.Lenses.Helpers.ScreenshotCapture.capture(routine_id) do
          {:ok, image_block} ->
            [image_block]
          {:error, reason} ->
            Logger.warning("Screenshot capture failed: \#{inspect(reason)}")
            []
        end
      else
        []
      end

    text_blocks ++ screenshot_blocks
  end
  ```

  ## Requirements

  - LiveView must subscribe to `screenshot:request:\#{routine_id}` PubSub topic
  - LiveView must have `phx-hook="ScreenshotCapture"` on target element
  - LiveView must handle `screenshot_captured` and `screenshot_failed` events
  - LiveView must store in ScreenshotCache and notify Engine process
  - ScreenshotCache must be running (added to Application supervision tree)

  ## Error Handling

  - Returns `{:error, :no_routine_id}` if routine_id is nil
  - Returns `{:error, :timeout}` if screenshot capture takes > 5 seconds
  - Returns `{:error, :cache_retrieval_failed}` if cache retrieval fails
  - LiveView should log errors from JavaScript hook
  """

  require Logger
  alias Koalemos.Caches.ScreenshotCache

  @timeout_ms 5000

  @doc """
  Capture a screenshot for the given routine.

  Returns `{:ok, image_block}` with a properly formatted image content block,
  or `{:error, reason}` if capture fails.

  ## Parameters

  - `routine_id` - The routine ID (must match LiveView's routine_id)

  ## Returns

  - `{:ok, %{type: "image", source: %{type: "base64", ...}}}` on success
  - `{:error, :no_routine_id}` if routine_id is nil
  - `{:error, :timeout}` if capture takes too long
  - `{:error, :cache_retrieval_failed}` if cache access fails

  ## Example

      case ScreenshotCapture.capture(routine_id) do
        {:ok, image_block} ->
          [image_block]
        {:error, reason} ->
          Logger.warning("Screenshot failed: \#{inspect(reason)}")
          []
      end
  """
  def capture(nil) do
    {:error, :no_routine_id}
  end

  def capture(routine_id) when is_binary(routine_id) do
    Logger.debug("[ScreenshotCapture] Requesting screenshot for routine #{routine_id}")

    # Spawn Task to handle async screenshot request
    # This keeps screenshot logic out of Engine's message queue
    task =
      Task.async(fn ->
        # Subscribe to response topic
        Phoenix.PubSub.subscribe(Koalemos.PubSub, "screenshot:response:#{routine_id}")

        # 1. Broadcast PubSub request to trigger screenshot capture in LiveView
        Phoenix.PubSub.broadcast(
          Koalemos.PubSub,
          "screenshot:request:#{routine_id}",
          {:screenshot_request, %{routine_id: routine_id, timestamp: DateTime.utc_now()}}
        )

        # 2. Wait for screenshot capture to complete (with timeout)
        receive do
          {:screenshot_ready, ^routine_id} ->
            Logger.debug(
              "[ScreenshotCapture] Screenshot ready notification received for #{routine_id}"
            )

            # 3. Retrieve from ScreenshotCache
            case ScreenshotCache.get(routine_id) do
              {:ok, base64_data} ->
                # Return formatted image content block
                {:ok,
                 %{
                   type: "image",
                   source: %{
                     type: "base64",
                     media_type: "image/png",
                     data: base64_data
                   }
                 }}

              {:error, reason} ->
                Logger.error(
                  "[ScreenshotCapture] Failed to retrieve screenshot from cache: #{inspect(reason)}"
                )

                {:error, :cache_retrieval_failed}
            end
        after
          @timeout_ms ->
            Logger.warning(
              "[ScreenshotCapture] Screenshot capture timeout after #{@timeout_ms}ms for #{routine_id}"
            )

            {:error, :timeout}
        end
      end)

    # Wait for task (slightly longer than receive timeout to avoid race)
    Task.await(task, @timeout_ms + 1000)
  end
end
