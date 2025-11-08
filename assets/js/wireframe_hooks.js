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

/**
 * JavaScriptUpdater Hook (Sprint 6)
 *
 * Dynamically updates JavaScript variables and functions when agent modifies them.
 * Solves the problem that script tags don't re-execute on LiveView updates.
 *
 * Usage:
 *   <div phx-hook="JavaScriptUpdater" id="js-updater"></div>
 */
WireframeHooks.JavaScriptUpdater = {
  mounted() {
    console.log("[JavaScriptUpdater] Hook mounted - ready to receive JS updates")

    // Track attached handlers so we can remove them before re-attaching
    this.attachedHandlers = new Map() // Map<elementId, Map<eventType, handlerFunc>>

    // Listen for init script changes - reload page for clean initialization
    // TODO BACKLOG: Implement "soft reload" (reset state without browser reload)
    this.handleEvent("reload_page", () => {
      console.log("[JavaScriptUpdater] Init scripts changed - reloading page for clean state")
      window.location.reload()
    })

    // Listen for variable updates from server
    this.handleEvent("update_variables", ({variables}) => {
      console.log("[JavaScriptUpdater] Updating variables:", variables)
      Object.entries(variables).forEach(([name, value]) => {
        window[name] = value
        console.log(`[JavaScriptUpdater] Set window.${name} =`, value)
      })
    })

    // Listen for function updates from server
    this.handleEvent("update_functions", ({functions}) => {
      console.log("[JavaScriptUpdater] Updating functions:", Object.keys(functions))
      Object.entries(functions).forEach(([name, code]) => {
        try {
          // Evaluate function code and assign to window
          window[name] = eval(`(${code})`)
          console.log(`[JavaScriptUpdater] Set window.${name} = function`)
        } catch (error) {
          console.error(`[JavaScriptUpdater] Failed to update function ${name}:`, error)
        }
      })
    })

    // Listen for handler updates from server
    this.handleEvent("update_handlers", ({handlers}) => {
      console.log("[JavaScriptUpdater] Processing handler updates:", handlers)

      Object.entries(handlers).forEach(([elementId, events]) => {
        const el = document.getElementById(elementId)
        if (!el) {
          console.warn(`[JavaScriptUpdater] Element not found: ${elementId}`)
          return
        }

        const oldHandlers = this.attachedHandlers.get(elementId) || new Map()
        const newHandlers = new Map()
        const oldEventTypes = new Set(oldHandlers.keys())
        const newEventTypes = new Set(Object.keys(events))

        // Process each new handler
        Object.entries(events).forEach(([eventType, handlerSpec]) => {
          const params = handlerSpec.params || []
          const body = handlerSpec.body || ""

          // Check if this handler changed
          const oldHandler = oldHandlers.get(eventType)
          const handlerChanged = !oldHandler ||
            JSON.stringify(oldHandler.spec) !== JSON.stringify(handlerSpec)

          if (handlerChanged) {
            // Remove old handler if it exists
            if (oldHandler) {
              el.removeEventListener(eventType, oldHandler.func)
              console.log(`[JavaScriptUpdater] Replaced ${eventType} handler on ${elementId}`)
            } else {
              console.log(`[JavaScriptUpdater] Added ${eventType} handler to ${elementId}`)
            }

            try {
              // Create and attach new handler function
              const handlerFunc = new Function(...params, body)
              el.addEventListener(eventType, handlerFunc)

              // Store handler with its spec for comparison
              newHandlers.set(eventType, {func: handlerFunc, spec: handlerSpec})
            } catch (error) {
              console.error(`[JavaScriptUpdater] Failed to attach ${eventType} handler to ${elementId}:`, error)
            }
          } else {
            // Handler unchanged - keep the old one
            console.log(`[JavaScriptUpdater] Kept unchanged ${eventType} handler on ${elementId}`)
            newHandlers.set(eventType, oldHandler)
          }
        })

        // Remove handlers that are no longer in the new set
        oldEventTypes.forEach(eventType => {
          if (!newEventTypes.has(eventType)) {
            const oldHandler = oldHandlers.get(eventType)
            el.removeEventListener(eventType, oldHandler.func)
            console.log(`[JavaScriptUpdater] Removed ${eventType} handler from ${elementId}`)
          }
        })

        // Store updated handlers for this element
        this.attachedHandlers.set(elementId, newHandlers)
      })
    })
  },

  destroyed() {
    console.log("[JavaScriptUpdater] Hook destroyed - cleaning up handlers")

    // Clean up all attached handlers
    this.attachedHandlers.forEach((handlers, elementId) => {
      const el = document.getElementById(elementId)
      if (el) {
        handlers.forEach((handlerData, eventType) => {
          el.removeEventListener(eventType, handlerData.func)
        })
      }
    })

    this.attachedHandlers.clear()
  }
}

export default WireframeHooks
