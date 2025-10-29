// Wireframe-specific LiveView hooks
// Loaded globally but only activates on elements with phx-hook="ScreenshotCapture"

const WireframeHooks = {}

/**
 * ScreenshotCapture Hook
 *
 * Captures screenshots from DOM elements using html2canvas library.
 * Screenshots are converted to base64 PNG and sent to Elixir via LiveView events.
 *
 * Sprint 2: Manual trigger via button click
 * Sprint 3: Will add auto-capture and tool integration
 *
 * Usage:
 *   <div phx-hook="ScreenshotCapture" id="capture-target">
 *     <!-- Content to capture -->
 *   </div>
 *
 * Requires:
 *   - html2canvas library (loaded from CDN)
 *   - LiveView event handler for "screenshot_captured"
 */
WireframeHooks.ScreenshotCapture = {
  /**
   * Hook mounted - setup and load html2canvas
   */
  mounted() {
    console.log("[ScreenshotCapture] Hook mounted on element:", this.el.id)

    // State
    this.html2canvasReady = false
    this.lastScreenshotTime = null
    this.isCapturing = false

    // Load html2canvas library from CDN
    this.loadHtml2Canvas()

    // Listen for manual capture trigger from LiveView
    this.handleEvent("trigger_screenshot_capture", () => {
      console.log("[ScreenshotCapture] Manual capture triggered")
      this.captureScreenshot()
    })
  },

  /**
   * Hook updated - not needed for Sprint 2
   */
  updated() {
    // Sprint 3 TODO: Handle auto-capture on content changes
  },

  /**
   * Hook destroyed - cleanup
   */
  destroyed() {
    console.log("[ScreenshotCapture] Hook destroyed")
    // No persistent listeners to clean up in Sprint 2
  },

  /**
   * Load html2canvas library from CDN
   */
  loadHtml2Canvas() {
    // Check if already loaded
    if (window.html2canvas) {
      console.log("[ScreenshotCapture] html2canvas already loaded")
      this.html2canvasReady = true
      return
    }

    console.log("[ScreenshotCapture] Loading html2canvas from CDN...")

    const script = document.createElement('script')
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js'
    script.async = true

    script.onload = () => {
      console.log("[ScreenshotCapture] html2canvas loaded successfully")
      this.html2canvasReady = true
    }

    script.onerror = (error) => {
      console.error("[ScreenshotCapture] Failed to load html2canvas:", error)
      this.pushEvent("screenshot_failed", {
        error: "Failed to load html2canvas library",
        timestamp: Date.now()
      })
    }

    document.head.appendChild(script)
  },

  /**
   * Capture screenshot of the element
   *
   * Converts the element to a canvas using html2canvas,
   * then encodes as base64 PNG and sends to LiveView.
   */
  async captureScreenshot() {
    // Check if library is ready
    if (!this.html2canvasReady || !window.html2canvas) {
      console.warn("[ScreenshotCapture] html2canvas not ready, skipping capture")
      return
    }

    // Check if already capturing (prevent concurrent captures)
    if (this.isCapturing) {
      console.log("[ScreenshotCapture] Capture already in progress, skipping")
      return
    }

    // Check cooldown (prevent rapid captures)
    const now = Date.now()
    const cooldownMs = 2000 // 2 second cooldown

    if (this.lastScreenshotTime && (now - this.lastScreenshotTime) < cooldownMs) {
      const remaining = Math.ceil((cooldownMs - (now - this.lastScreenshotTime)) / 1000)
      console.log(`[ScreenshotCapture] Cooldown active, ${remaining}s remaining`)
      return
    }

    // Check for empty content
    const rect = this.el.getBoundingClientRect()
    if (rect.height === 0 || rect.width === 0) {
      console.log("[ScreenshotCapture] Skipping capture - element has no dimensions")
      return
    }

    try {
      this.isCapturing = true
      console.log("[ScreenshotCapture] Starting screenshot capture...")

      // Capture element to canvas
      const canvas = await window.html2canvas(this.el, {
        backgroundColor: '#ffffff',
        scale: 1,
        useCORS: true,
        allowTaint: false,
        removeContainer: true,
        height: this.el.scrollHeight,
        windowHeight: this.el.scrollHeight,
        logging: false  // Disable html2canvas console logs
      })

      console.log(`[ScreenshotCapture] Canvas created: ${canvas.width}x${canvas.height}`)

      // Convert canvas to base64 PNG
      const dataUrl = canvas.toDataURL('image/png')
      const base64Data = dataUrl.split(',')[1] // Remove "data:image/png;base64," prefix

      // Send to LiveView
      this.pushEvent("screenshot_captured", {
        data: base64Data,
        format: "png",
        width: canvas.width,
        height: canvas.height,
        timestamp: now
      })

      // Update state
      this.lastScreenshotTime = now

      console.log(`[ScreenshotCapture] Screenshot captured and sent (${Math.round(base64Data.length / 1024)}KB)`)

    } catch (error) {
      console.error("[ScreenshotCapture] Capture failed:", error)

      this.pushEvent("screenshot_failed", {
        error: error.message || "Screenshot capture failed",
        timestamp: Date.now()
      })

    } finally {
      this.isCapturing = false
    }
  }
}

export default WireframeHooks
