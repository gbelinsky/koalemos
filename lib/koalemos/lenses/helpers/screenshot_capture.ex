defmodule Koalemos.Lenses.Helpers.ScreenshotCapture do
  @moduledoc """
  Helper for capturing screenshots using server-side Puppeteer rendering.

  ## Overview

  This module provides a screenshot capture system for lenses that need to include
  visual context from the current page state. It uses server-side rendering with
  Puppeteer to capture pixel-perfect screenshots with full CSS support including
  gradients, transforms, and filters.

  ## Architecture

  **Server-Side Rendering (Current - M6+)**

  The screenshot system uses Puppeteer via NodeJS.Supervisor:

  1. Retrieve lens_state from WireframeStateCache
  2. Convert lens_state to standalone HTML (ScreenshotRenderer)
  3. Send HTML to Puppeteer for headless Chrome rendering
  4. Receive base64 PNG with full CSS gradient support
  5. Store in ScreenshotCache for caching/reuse
  6. Return formatted image content block

  **Benefits:**
  - Pixel-perfect screenshots with CSS gradients, transforms, filters
  - No client-side dependencies or LiveView communication
  - Faster and more reliable (no PubSub/WebSocket overhead)
  - Works without active browser session

  **Legacy Client-Side (Pre-M6)**

  Previously used html-to-image via JavaScript hook, but couldn't properly
  capture CSS gradients. See git history for old implementation.

  ## ScreenshotCache

  **Module:** `Koalemos.Caches.ScreenshotCache`

  **Purpose:** In-memory storage for captured screenshots

  **Operations:**
  - `put(routine_id, base64_data)` - Store screenshot
  - `get(routine_id)` - Retrieve screenshot
  - `clear(routine_id)` - Remove screenshot

  ## Usage in Lenses

  ```elixir
  def provide_context(state) do
    text_blocks = [%{type: "text", text: "Base context"}]

    screenshot_blocks =
      case Koalemos.Lenses.Helpers.ScreenshotCapture.capture(state.routine_id) do
        {:ok, image_block} ->
          [image_block]
        {:error, reason} ->
          Logger.warning("Screenshot capture failed: \#{inspect(reason)}")
          []
      end

    text_blocks ++ screenshot_blocks
  end
  ```

  ## Requirements

  - WireframeStateCache must contain lens_state for the routine_id
  - NodeJS.Supervisor must be running with Puppeteer installed
  - ScreenshotCache must be running (added to Application supervision tree)

  ## Error Handling

  - Returns `{:error, :no_routine_id}` if routine_id is nil
  - Returns `{:error, :no_lens_state}` if lens_state not found in cache
  - Returns `{:error, reason}` if Puppeteer rendering fails
  """

  require Logger
  alias Koalemos.Caches.ScreenshotCache
  alias Koalemos.Caches.WireframeStateCache
  alias Koalemos.ScreenshotRenderer

  @doc """
  Capture a screenshot for the given routine using server-side rendering.

  Returns `{:ok, image_block}` with a properly formatted image content block,
  or `{:error, reason}` if capture fails.

  ## Parameters

  - `routine_id` - The routine ID (must have lens_state in WireframeStateCache)
  - `opts` - Optional keyword list:
    - `:use_live_dom` - Boolean, use running DOM instead of designed DOM (default: false)
    - `:viewport` - Map with :width and :height (default: %{width: 1280, height: 720})
    - `:full_page` - Boolean, capture full page (default: false)

  ## Returns

  - `{:ok, %{type: "image", source: %{type: "base64", ...}}}` on success
  - `{:error, :no_routine_id}` if routine_id is nil
  - `{:error, :no_lens_state}` if lens_state not found
  - `{:error, reason}` if Puppeteer rendering fails

  ## Example

      case ScreenshotCapture.capture(routine_id) do
        {:ok, image_block} ->
          [image_block]
        {:error, reason} ->
          Logger.warning("Screenshot failed: \#{inspect(reason)}")
          []
      end
  """
  def capture(routine_id, opts \\ [])

  def capture(nil, _opts) do
    {:error, :no_routine_id}
  end

  def capture(routine_id, opts) when is_binary(routine_id) do
    use_live_dom = Keyword.get(opts, :use_live_dom, false)
    dom_type = if use_live_dom, do: "LIVE", else: "DESIGNED"

    Logger.info("[ScreenshotCapture] 📸 SCREENSHOT CAPTURE CALLED for routine #{routine_id} (#{dom_type} DOM)")

    # 1. Retrieve lens_state from cache (returns lens_state or nil, not a tuple)
    Logger.debug("[ScreenshotCapture] Retrieving lens_state from WireframeStateCache...")

    case WireframeStateCache.get_state(routine_id) do
      nil ->
        Logger.warning(
          "[ScreenshotCapture] ⚠️  No lens_state found in cache for routine #{routine_id}"
        )

        {:error, :no_lens_state}

      lens_state when is_map(lens_state) ->
        Logger.info("[ScreenshotCapture] ✅ lens_state retrieved, calling ScreenshotRenderer with #{dom_type} DOM...")

        # 2. Use ScreenshotRenderer to capture via Puppeteer
        renderer_opts = [routine_id: routine_id] ++ opts

        case ScreenshotRenderer.capture_from_lens_state(lens_state, renderer_opts) do
          {:ok, base64_data} ->
            # 3. Store in ScreenshotCache for consistency with existing code
            Logger.info("[ScreenshotCapture] 💾 Storing SERVER-SIDE screenshot in ScreenshotCache for #{routine_id}")
            :ok = ScreenshotCache.put(routine_id, base64_data)

            # 4. Return formatted image content block
            Logger.info("[ScreenshotCapture] ✅ SERVER-SIDE screenshot complete, returning image block")
            {:ok,
             %{
               type: "image",
               source: %{
                 type: "base64",
                 media_type: "image/png",
                 data: base64_data
               }
             }}

          {:error, reason} = error ->
            Logger.error(
              "[ScreenshotCapture] ❌ Puppeteer rendering failed for #{routine_id}: #{inspect(reason)}"
            )

            error
        end
    end
  end
end
