// Wireframe-specific LiveView hooks
// Loaded globally but only activates on elements with phx-hook="ScreenshotCapture"

// Infrastructure console - never captured, only shows in browser
// Uses the original console methods saved by early interception script
// All hook code should use this instead of bare console.log/warn/error
//
// NOTE: The early script in wireframe_preview_live.ex creates window.__originalConsole
// with bound methods (console.log.bind(console)). We just call them directly.
const INFRASTRUCTURE_CONSOLE = {
  log: function(...args) {
    if (window.__originalConsole?.log) {
      window.__originalConsole.log(...args)
    } else {
      // Debug: __originalConsole not available
      console.log('[INFRA] No __originalConsole:', ...args)
    }
  },
  warn: function(...args) {
    if (window.__originalConsole?.warn) {
      window.__originalConsole.warn(...args)
    } else {
      console.warn('[INFRA] No __originalConsole:', ...args)
    }
  },
  error: function(...args) {
    if (window.__originalConsole?.error) {
      window.__originalConsole.error(...args)
    } else {
      console.error('[INFRA] No __originalConsole:', ...args)
    }
  }
}

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
    INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] Hook mounted on element:", this.el.id)

    // State
    this.html2canvasReady = false
    this.lastScreenshotTime = null
    this.isCapturing = false

    // Expose for other hooks (Sprint 7 Phase 5)
    window.__screenshotHook = this

    // Load html2canvas library from CDN
    this.loadHtml2Canvas()

    // Listen for manual capture trigger from LiveView
    this.handleEvent("trigger_screenshot_capture", () => {
      INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] Manual capture triggered")
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
    INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] Hook destroyed")
    // No persistent listeners to clean up in Sprint 2
  },

  /**
   * Load html2canvas library from CDN
   */
  loadHtml2Canvas() {
    // Check if already loaded
    if (window.html2canvas) {
      INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] html2canvas already loaded")
      this.html2canvasReady = true
      return
    }

    INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] Loading html2canvas from CDN...")

    const script = document.createElement('script')
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js'
    script.async = true

    script.onload = () => {
      INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] html2canvas loaded successfully")
      this.html2canvasReady = true
    }

    script.onerror = (error) => {
      INFRASTRUCTURE_CONSOLE.error("[ScreenshotCapture] Failed to load html2canvas:", error)
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
      INFRASTRUCTURE_CONSOLE.warn("[ScreenshotCapture] html2canvas not ready, skipping capture")
      return
    }

    // Check if already capturing (prevent concurrent captures)
    if (this.isCapturing) {
      INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] Capture already in progress, skipping")
      return
    }

    // Check cooldown (prevent rapid captures)
    const now = Date.now()
    const cooldownMs = 2000 // 2 second cooldown

    if (this.lastScreenshotTime && (now - this.lastScreenshotTime) < cooldownMs) {
      const remaining = Math.ceil((cooldownMs - (now - this.lastScreenshotTime)) / 1000)
      INFRASTRUCTURE_CONSOLE.log(`[ScreenshotCapture] Cooldown active, ${remaining}s remaining`)
      return
    }

    try {
      this.isCapturing = true
      INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] Starting screenshot capture...")

      // Use shared capture logic (Sprint 7 Phase 5 refactor)
      const { canvas, base64 } = await this._performCapture(this.el)

      // Send to LiveView
      this.pushEvent("screenshot_captured", {
        data: base64,
        format: "png",
        width: canvas.width,
        height: canvas.height,
        timestamp: now
      })

      // Update state
      this.lastScreenshotTime = now

      INFRASTRUCTURE_CONSOLE.log(`[ScreenshotCapture] Screenshot captured and sent (${Math.round(base64.length / 1024)}KB)`)

    } catch (error) {
      INFRASTRUCTURE_CONSOLE.error("[ScreenshotCapture] Capture failed:", error)

      this.pushEvent("screenshot_failed", {
        error: error.message || "Screenshot capture failed",
        timestamp: Date.now()
      })

    } finally {
      this.isCapturing = false
    }
  },

  /**
   * Core screenshot capture logic (Sprint 7 Phase 5)
   *
   * Shared by both captureScreenshot() (manual) and captureScreenshotBlocking() (automatic).
   *
   * @param {HTMLElement} element - Element to capture
   * @returns {Promise<{canvas: HTMLCanvasElement, base64: string}>}
   * @private
   */
  async _performCapture(element) {
    if (!element) {
      throw new Error("No element provided for capture")
    }

    // Check dimensions
    const rect = element.getBoundingClientRect()
    if (rect.height === 0 || rect.width === 0) {
      throw new Error("Element has no dimensions")
    }

    // Capture element to canvas
    const canvas = await window.html2canvas(element, {
      backgroundColor: '#ffffff',
      scale: 1,
      useCORS: true,
      allowTaint: false,
      removeContainer: true,
      height: element.scrollHeight,
      windowHeight: element.scrollHeight,
      logging: false  // Disable html2canvas console logs
    })

    INFRASTRUCTURE_CONSOLE.log(`[ScreenshotCapture] Canvas created: ${canvas.width}x${canvas.height}`)

    // Convert canvas to base64 PNG
    const dataUrl = canvas.toDataURL('image/png')
    const base64Data = dataUrl.split(',')[1] // Remove "data:image/png;base64," prefix

    return { canvas, base64: base64Data }
  },

  /**
   * Blocking screenshot capture for state snapshots (Sprint 7 Phase 5)
   *
   * Used by JavaScriptUpdater.captureCompleteState() to include screenshots
   * in state snapshots. Unlike captureScreenshot(), this method:
   * - Returns data directly (no pushEvent)
   * - Optionally skips cooldown check
   * - Captures document #root or body (not this.el)
   * - Returns null on failure (doesn't throw)
   *
   * @param {Object} opts - Options
   * @param {boolean} opts.skipCooldown - Skip cooldown check (default: false)
   * @returns {Promise<string|null>} Base64 PNG data or null on failure
   */
  async captureScreenshotBlocking(opts = {}) {
    // Check if library is ready
    if (!this.html2canvasReady || !window.html2canvas) {
      INFRASTRUCTURE_CONSOLE.warn("[ScreenshotCapture] html2canvas not ready for blocking capture")
      return null
    }

    // Check cooldown unless explicitly skipped
    if (!opts.skipCooldown) {
      const now = Date.now()
      const cooldownMs = 2000

      if (this.lastScreenshotTime && (now - this.lastScreenshotTime) < cooldownMs) {
        INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] Cooldown active, skipping blocking capture")
        return null
      }
    }

    try {
      INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] Starting blocking capture...")

      // Capture #root element or body (for state snapshots)
      const element = document.getElementById('root') || document.body
      const { canvas, base64 } = await this._performCapture(element)

      INFRASTRUCTURE_CONSOLE.log(`[ScreenshotCapture] Blocking capture complete (${Math.round(base64.length / 1024)}KB)`)

      return base64

    } catch (error) {
      INFRASTRUCTURE_CONSOLE.error("[ScreenshotCapture] Blocking capture failed:", error)
      return null
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
    INFRASTRUCTURE_CONSOLE.log("[JavaScriptUpdater] Hook mounted - ready to receive JS updates")

    // Track attached handlers so we can remove them before re-attaching
    this.attachedHandlers = new Map() // Map<elementId, Map<eventType, handlerFunc>>

    // Listen for init script changes - reload page for clean initialization
    // TODO BACKLOG: Implement "soft reload" (reset state without browser reload)
    this.handleEvent("reload_page", () => {
      INFRASTRUCTURE_CONSOLE.log("[JavaScriptUpdater] Init scripts changed - reloading page for clean state")
      window.location.reload()
    })

    // Listen for variable updates from server
    this.handleEvent("update_variables", ({variables}) => {
      INFRASTRUCTURE_CONSOLE.log("[JavaScriptUpdater] Updating variables:", variables)
      Object.entries(variables).forEach(([name, value]) => {
        window[name] = value
        INFRASTRUCTURE_CONSOLE.log(`[JavaScriptUpdater] Set window.${name} =`, value)
      })
    })

    // Listen for function updates from server
    this.handleEvent("update_functions", ({functions}) => {
      INFRASTRUCTURE_CONSOLE.log("[JavaScriptUpdater] Updating functions:", Object.keys(functions))
      Object.entries(functions).forEach(([name, code]) => {
        try {
          // Evaluate function code and assign to window
          window[name] = eval(`(${code})`)
          INFRASTRUCTURE_CONSOLE.log(`[JavaScriptUpdater] Set window.${name} = function`)
        } catch (error) {
          INFRASTRUCTURE_CONSOLE.error(`[JavaScriptUpdater] Failed to update function ${name}:`, error)
        }
      })
    })

    // Listen for handler updates from server
    this.handleEvent("update_handlers", ({handlers}) => {
      INFRASTRUCTURE_CONSOLE.log("[JavaScriptUpdater] Processing handler updates:", handlers)

      Object.entries(handlers).forEach(([elementId, events]) => {
        const el = document.getElementById(elementId)
        if (!el) {
          INFRASTRUCTURE_CONSOLE.warn(`[JavaScriptUpdater] Element not found: ${elementId}`)
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
              INFRASTRUCTURE_CONSOLE.log(`[JavaScriptUpdater] Replaced ${eventType} handler on ${elementId}`)
            } else {
              INFRASTRUCTURE_CONSOLE.log(`[JavaScriptUpdater] Added ${eventType} handler to ${elementId}`)
            }

            try {
              // Create and attach new handler function
              const handlerFunc = new Function(...params, body)
              el.addEventListener(eventType, handlerFunc)

              // Store handler with its spec for comparison
              newHandlers.set(eventType, {func: handlerFunc, spec: handlerSpec})
            } catch (error) {
              INFRASTRUCTURE_CONSOLE.error(`[JavaScriptUpdater] Failed to attach ${eventType} handler to ${elementId}:`, error)
            }
          } else {
            // Handler unchanged - keep the old one
            INFRASTRUCTURE_CONSOLE.log(`[JavaScriptUpdater] Kept unchanged ${eventType} handler on ${elementId}`)
            newHandlers.set(eventType, oldHandler)
          }
        })

        // Remove handlers that are no longer in the new set
        oldEventTypes.forEach(eventType => {
          if (!newEventTypes.has(eventType)) {
            const oldHandler = oldHandlers.get(eventType)
            el.removeEventListener(eventType, oldHandler.func)
            INFRASTRUCTURE_CONSOLE.log(`[JavaScriptUpdater] Removed ${eventType} handler from ${elementId}`)
          }
        })

        // Store updated handlers for this element
        this.attachedHandlers.set(elementId, newHandlers)
      })
    })

    // Listen for state capture requests (Sprint 7)
    this.handleEvent("capture_state", (opts) => {
      INFRASTRUCTURE_CONSOLE.log("[JavaScriptUpdater] State capture requested")
      this.captureCompleteState(opts)
    })

    // Initialize state for console tracking (Sprint 7 Phase 4)
    // Start from 0 so we capture ALL console output including init scripts
    // that ran before this hook mounted
    this.lastSnapshotTime = 0

    // Use the global console buffer created by early interception script
    // This buffer already captured init script console output
    this.consoleBuffer = window.__consoleBuffer || []
    this.originalConsole = window.__originalConsole || {}

    INFRASTRUCTURE_CONSOLE.log(`[JavaScriptUpdater] Console tracking initialized, buffer has ${this.consoleBuffer.length} messages`)

    // Listen for interaction execution requests (Sprint 7 Phase 3)
    this.handleEvent("execute_interaction", (args) => {
      INFRASTRUCTURE_CONSOLE.log("[Interaction] Received execution request:", args)
      this.executeInteraction(args)
    })
  },



  /**
   * Get console messages since last snapshot
   * Sprint 7 Phase 4
   */
  getConsoleSinceLastSnapshot() {
    // Filter messages that occurred after last snapshot
    const messages = this.consoleBuffer.filter(msg =>
      msg.timestamp >= this.lastSnapshotTime
    )

    return messages
  },

  /**
   * Capture complete state (DOM + console + screenshot)
   * Sprint 7 Phase 2
   */
  async captureCompleteState(opts = {}) {
    INFRASTRUCTURE_CONSOLE.log("[StateCapture] Capturing complete state...")

    try {
      // Serialize DOM tree (capture only wireframe content, not LiveView wrapper)
      const wireframeRoot = document.getElementById('root')
      if (!wireframeRoot) {
        INFRASTRUCTURE_CONSOLE.warn("[StateCapture] Wireframe root element not found, falling back to body")
      }
      const dom_tree = this.serializeDOM(wireframeRoot || document.body)

      // Gather console messages since last snapshot (Sprint 7 Phase 4)
      const console_messages = this.getConsoleSinceLastSnapshot()

      // Capture screenshot (Sprint 7 Phase 5)
      let screenshot = null
      if (!opts.skip_screenshot && window.__screenshotHook) {
        screenshot = await window.__screenshotHook.captureScreenshotBlocking({ skipCooldown: true })
        if (screenshot) {
          INFRASTRUCTURE_CONSOLE.log(`[StateCapture] Screenshot captured (${Math.round(screenshot.length / 1024)}KB)`)
        } else {
          INFRASTRUCTURE_CONSOLE.warn("[StateCapture] Screenshot capture returned null")
        }
      } else if (!window.__screenshotHook) {
        INFRASTRUCTURE_CONSOLE.warn("[StateCapture] Screenshot hook not available")
      }

      // Send snapshot back to LiveView
      this.pushEvent("state_snapshot", {
        dom_tree: dom_tree,
        console_messages: console_messages,
        screenshot: screenshot,
        timestamp: Date.now()
      })

      this.lastSnapshotTime = Date.now()
      INFRASTRUCTURE_CONSOLE.log("[StateCapture] State snapshot sent successfully")
    } catch (error) {
      INFRASTRUCTURE_CONSOLE.error("[StateCapture] Failed to capture state:", error)
      // Still send partial data if possible
      this.pushEvent("state_snapshot", {
        error: error.message,
        timestamp: Date.now()
      })
    }
  },

  /**
   * Serialize DOM element to map structure
   * Sprint 7 Phase 2
   */
  serializeDOM(element) {
    // Skip script and style tags (not part of user content)
    if (element.tagName === 'SCRIPT' || element.tagName === 'STYLE') {
      return null
    }

    // Skip our hook div (hidden helper div)
    if (element.id === 'js-updater') {
      return null
    }

    // Get all attributes (exclude class/id since they're handled separately)
    const attributes = {}
    Array.from(element.attributes || []).forEach(attr => {
      // Skip phx-* attributes (LiveView internal)
      // Skip class/id (handled separately for consistent formatting)
      if (!attr.name.startsWith('phx-') &&
          !attr.name.startsWith('data-phx-') &&
          attr.name !== 'class' &&
          attr.name !== 'id') {
        attributes[attr.name] = attr.value
      }
    })

    // Get text content (only if element has no children or only text nodes)
    let content = null
    if (element.childNodes.length === 1 && element.childNodes[0].nodeType === 3) {
      content = element.textContent
    }

    // Serialize children
    const children = []
    Array.from(element.children || []).forEach(child => {
      const serialized = this.serializeDOM(child)
      if (serialized) {
        children.push(serialized)
      }
    })

    return {
      tag: element.tagName.toLowerCase(),
      id: element.id || null,
      classes: Array.from(element.classList || []),
      attributes: attributes,
      content: content,
      children: children
    }
  },

  /**
   * Execute interaction in preview
   * Sprint 7 Phase 3
   */
  executeInteraction(command) {
    INFRASTRUCTURE_CONSOLE.log("[Interaction] Executing:", command)

    try {
      // Execute the requested action
      switch(command.action) {
        case "click":
          this.triggerClick(command.element_id)
          break
        case "fill_input":
          this.fillInput(command.element_id, command.value)
          break
        case "submit_form":
          this.submitForm(command.element_id)
          break
        case "execute_js":
          this.executeJavaScript(command.javascript)
          break
        default:
          throw new Error(`Unknown interaction action: ${command.action}`)
      }

      // Wait a bit for DOM changes to settle, then notify completion
      setTimeout(() => {
        this.pushEvent("interaction_complete", {
          success: true,
          action: command.action
        })
      }, 300)

    } catch (error) {
      INFRASTRUCTURE_CONSOLE.error("[Interaction] Failed:", error)
      this.pushEvent("interaction_complete", {
        success: false,
        action: command.action,
        error: error.message
      })
    }
  },

  /**
   * Trigger click on element
   * Sprint 7 Phase 3
   */
  triggerClick(elementId) {
    const el = document.getElementById(elementId)
    if (!el) {
      throw new Error(`Element not found: ${elementId}`)
    }
    INFRASTRUCTURE_CONSOLE.log(`[Interaction] Clicking element: ${elementId}`)
    el.click()
  },

  /**
   * Fill input element with value
   * Sprint 7 Phase 3
   */
  fillInput(elementId, value) {
    const el = document.getElementById(elementId)
    if (!el) {
      throw new Error(`Element not found: ${elementId}`)
    }
    INFRASTRUCTURE_CONSOLE.log(`[Interaction] Filling ${elementId} with: ${value}`)
    el.value = value
    // Dispatch input and change events to trigger any listeners
    el.dispatchEvent(new Event('input', { bubbles: true }))
    el.dispatchEvent(new Event('change', { bubbles: true }))
  },

  /**
   * Submit form
   * Sprint 7 Phase 3
   */
  submitForm(elementId) {
    const el = document.getElementById(elementId)
    if (!el) {
      throw new Error(`Element not found: ${elementId}`)
    }
    INFRASTRUCTURE_CONSOLE.log(`[Interaction] Submitting form: ${elementId}`)
    // Dispatch submit event (respects preventDefault if handler uses it)
    el.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
  },

  /**
   * Execute arbitrary JavaScript
   * Sprint 7 Phase 3
   */
  executeJavaScript(code) {
    INFRASTRUCTURE_CONSOLE.log(`[Interaction] Executing JavaScript: ${code.substring(0, 50)}...`)
    // Execute in global scope using Function constructor
    const func = new Function(code)
    func()
  },

  destroyed() {
    INFRASTRUCTURE_CONSOLE.log("[JavaScriptUpdater] Hook destroyed - cleaning up handlers")

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

    // Console interception is handled by global script, no cleanup needed
    // Just clear the buffer reference
    this.consoleBuffer = null
  }
}

export default WireframeHooks
