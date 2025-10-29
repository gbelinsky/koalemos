// Wireframe-specific LiveView hooks
// Only imported by wireframe preview pages (not loaded globally)

const WireframeHooks = {}

/**
 * ScreenshotCapture Hook
 *
 * Captures screenshots from wireframe preview iframes and sends them
 * to the Elixir backend via PubSub.
 *
 * Sprint 1: Scaffold only - no actual capture logic yet
 * Sprint 2: Will implement canvas-based screenshot capture
 *
 * Usage:
 *   Add phx-hook="ScreenshotCapture" to an element on the wireframe page
 */
WireframeHooks.ScreenshotCapture = {
  mounted() {
    console.log("[ScreenshotCapture] Hook mounted")

    // Sprint 2 TODO:
    // - Setup iframe listeners
    // - Create canvas element for capture
    // - Setup PubSub listeners for screenshot requests
  },

  updated() {
    // Sprint 2 TODO:
    // - Handle screenshot request events from Elixir
    // - Trigger screenshot capture
  },

  destroyed() {
    // Sprint 2 TODO:
    // - Cleanup listeners
    // - Remove canvas elements
  }
}

export default WireframeHooks
