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
 * Captures screenshots from DOM elements using html-to-image library.
 * Screenshots are converted to base64 PNG and sent to Elixir via LiveView events.
 *
 * Uses html-to-image (instead of html2canvas) for better CSS gradient support.
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
 *   - html-to-image library (loaded from CDN)
 *   - LiveView event handler for "screenshot_captured"
 */
WireframeHooks.ScreenshotCapture = {
  /**
   * Hook mounted - setup and load html-to-image
   */
  mounted() {
    INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] ⚡ Hook mounted at timestamp:", Date.now(), "element:", this.el.id)

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
   * Load screenshot library from CDN (html-to-image for better gradient support)
   */
  loadHtml2Canvas() {
    // Check if already loaded
    if (window.htmlToImage) {
      INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] html-to-image already loaded")
      this.html2canvasReady = true
      return
    }

    INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] Loading html-to-image from CDN...")

    const script = document.createElement('script')
    script.src = 'https://cdn.jsdelivr.net/npm/html-to-image@1.11.11/dist/html-to-image.js'
    script.async = true

    script.onload = () => {
      INFRASTRUCTURE_CONSOLE.log("[ScreenshotCapture] html-to-image loaded successfully")
      this.html2canvasReady = true
    }

    script.onerror = (error) => {
      INFRASTRUCTURE_CONSOLE.error("[ScreenshotCapture] Failed to load html-to-image:", error)
      this.pushEvent("screenshot_failed", {
        error: "Failed to load html-to-image library",
        timestamp: Date.now()
      })
    }

    document.head.appendChild(script)
  },

  /**
   * Capture screenshot of the element
   *
   * Converts the element to PNG using html-to-image,
   * then encodes as base64 PNG and sends to LiveView.
   */
  async captureScreenshot() {
    // Check if library is ready
    if (!this.html2canvasReady || !window.htmlToImage) {
      INFRASTRUCTURE_CONSOLE.warn("[ScreenshotCapture] html-to-image not ready, skipping capture")
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
    const isEmpty = rect.height === 0 || rect.width === 0

    // Handle empty wireframes with a blank placeholder canvas
    if (isEmpty) {
      INFRASTRUCTURE_CONSOLE.log('[ScreenshotCapture] Element has no dimensions, creating blank placeholder')

      // Create a small blank canvas to represent empty state
      const canvas = document.createElement('canvas')
      canvas.width = 100
      canvas.height = 100

      // Fill with white background
      const ctx = canvas.getContext('2d')
      ctx.fillStyle = '#ffffff'
      ctx.fillRect(0, 0, 100, 100)

      // Convert canvas to base64 PNG
      const dataUrl = canvas.toDataURL('image/png')
      const base64Data = dataUrl.split(',')[1]

      INFRASTRUCTURE_CONSOLE.log('[ScreenshotCapture] Blank placeholder created: 100x100')
      return { canvas, base64: base64Data }
    }

    // Capture element to PNG using html-to-image
    const dataUrl = await window.htmlToImage.toPng(element, {
      backgroundColor: '#ffffff',
      pixelRatio: 1,
      height: element.scrollHeight,
      width: element.scrollWidth
    })

    // Extract base64 data
    const base64Data = dataUrl.split(',')[1] // Remove "data:image/png;base64," prefix

    // Create a temporary canvas to get dimensions (html-to-image doesn't return canvas)
    const img = new Image()
    img.src = dataUrl
    await new Promise(resolve => { img.onload = resolve })

    const canvas = { width: img.width, height: img.height }
    INFRASTRUCTURE_CONSOLE.log(`[ScreenshotCapture] PNG created: ${canvas.width}x${canvas.height}`)

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
    if (!this.html2canvasReady || !window.htmlToImage) {
      INFRASTRUCTURE_CONSOLE.warn("[ScreenshotCapture] html-to-image not ready for blocking capture")
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
    INFRASTRUCTURE_CONSOLE.log("[JavaScriptUpdater] ⚡ Hook mounted at timestamp:", Date.now())

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

    // Listen for init script execution (Sprint 8 - post-mount execution)
    // Receives scripts from server and executes them after LiveView mount completes
    // This fixes the bug where init-generated DOM elements would disappear
    this.handleEvent("execute_init_scripts", ({scripts}) => {
      INFRASTRUCTURE_CONSOLE.log("[JavaScriptUpdater] 🚀 Received init scripts to execute:", Object.keys(scripts))

      // Track execution for debugging
      const startTime = Date.now()
      const scriptNames = Object.keys(scripts)
      const scriptCount = scriptNames.length

      INFRASTRUCTURE_CONSOLE.log(`[JavaScriptUpdater] Executing ${scriptCount} init scripts in order: ${scriptNames.join(', ')}`)

      try {
        // Execute each script in map iteration order
        // Note: Modern JavaScript preserves insertion order for object keys
        Object.entries(scripts).forEach(([name, code], index) => {
          try {
            INFRASTRUCTURE_CONSOLE.log(`[JavaScriptUpdater] [${index + 1}/${scriptCount}] Executing init script: ${name}`)

            // Execute in global scope (matches behavior of inline <script> tags)
            // Using Function constructor allows scripts to define globals, modify DOM, etc.
            const func = new Function(code)
            func()

            INFRASTRUCTURE_CONSOLE.log(`[JavaScriptUpdater] ✓ Init script '${name}' executed successfully`)
          } catch (error) {
            // Log error but continue with other scripts
            // This matches browser behavior: one script error doesn't halt others
            INFRASTRUCTURE_CONSOLE.error(`[JavaScriptUpdater] ✗ Init script '${name}' failed:`, error)
            console.error(`Init script '${name}' error:`, error) // Also log to captured console for agent visibility
          }
        })

        const duration = Date.now() - startTime
        INFRASTRUCTURE_CONSOLE.log(`[JavaScriptUpdater] ✅ Completed ${scriptCount} init scripts in ${duration}ms`)

        // Send acknowledgment back to server (Sprint 8 - screenshot timing fix)
        // This allows manage_init_scripts tool to wait for execution to complete
        // before returning, ensuring screenshots capture the correct state
        this.pushEvent("init_scripts_complete", {
          success: true,
          executed_count: scriptCount,
          duration_ms: duration,
          timestamp: Date.now()
        })
        INFRASTRUCTURE_CONSOLE.log("[JavaScriptUpdater] 📤 Sent init_scripts_complete acknowledgment to server")

      } catch (error) {
        INFRASTRUCTURE_CONSOLE.error("[JavaScriptUpdater] ❌ Fatal error executing init scripts:", error)
        console.error("Init scripts execution failed:", error) // Agent visibility

        // Send failure acknowledgment
        this.pushEvent("init_scripts_complete", {
          success: false,
          error: error.message,
          timestamp: Date.now()
        })
      }
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
   * Capture complete state (DOM + console + screenshot + variables)
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

      // Capture current variable values (M6 Quick Win)
      let variables = {}
      if (opts.variable_names && Array.isArray(opts.variable_names)) {
        opts.variable_names.forEach(varName => {
          // Capture the current value from window (even if undefined)
          // Note: We check if it exists to distinguish undefined from not-set
          if (varName in window) {
            variables[varName] = window[varName]
            INFRASTRUCTURE_CONSOLE.log(`[StateCapture] Captured ${varName} = ${JSON.stringify(window[varName])}`)
          } else {
            INFRASTRUCTURE_CONSOLE.warn(`[StateCapture] Variable ${varName} not found on window`)
          }
        })
        INFRASTRUCTURE_CONSOLE.log(`[StateCapture] Captured ${Object.keys(variables).length} variable values`)
      }

      // Send snapshot back to LiveView
      this.pushEvent("state_snapshot", {
        dom_tree: dom_tree,
        console_messages: console_messages,
        screenshot: screenshot,
        variables: variables,
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

    // For form inputs, capture current value (not just the static attribute)
    // This captures dynamic state like user-entered text
    if (element.tagName === 'INPUT' || element.tagName === 'TEXTAREA' || element.tagName === 'SELECT') {
      if (element.value !== undefined && element.value !== '') {
        attributes['value'] = element.value
      }
      // For checkboxes/radios, capture checked state
      if (element.type === 'checkbox' || element.type === 'radio') {
        if (element.checked) {
          attributes['checked'] = 'true'
        }
      }
    }

    // For canvas elements, capture current pixel content
    // This allows screenshots to show canvas drawings
    if (element.tagName === 'CANVAS') {
      try {
        // Capture canvas content as base64 data URL
        const dataURL = element.toDataURL('image/png')
        attributes['data-canvas-snapshot'] = dataURL

        const sizeKB = Math.round(dataURL.length / 1024)
        INFRASTRUCTURE_CONSOLE.log(`[StateCapture] Captured canvas ${element.id || '(no id)'}: ${sizeKB}KB`)
      } catch (error) {
        // Canvas may be tainted (CORS) or encounter other errors
        INFRASTRUCTURE_CONSOLE.warn(`[StateCapture] Failed to capture canvas ${element.id || '(no id)'}:`, error.message)
        attributes['data-canvas-error'] = error.message
      }
    }

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

/**
 * ConfigStorage Hook
 *
 * Manages non-sensitive configuration in browser localStorage.
 * Complements server-side ConfigStore for local preferences.
 *
 * Hierarchy (lowest to highest priority):
 * 1. Defaults (hardcoded)
 * 2. localStorage (browser preferences) <- This hook
 * 3. .koalemos/.config.json (project config)
 * 4. ~/.koalemos/.config.json (user config)
 * 5. Environment variables (server-side, highest)
 *
 * Stores:
 * - provider (anthropic, openai, ollama)
 * - anthropic_model (e.g., "claude-sonnet-4-5")
 * - openai_model (e.g., "gpt-4o")
 * - ollama_model (e.g., "qwen2.5:7b")
 * - ollama_base_url (e.g., "http://localhost:11434")
 *
 * Usage:
 *   <div phx-hook="ConfigStorage" id="config-storage"></div>
 */
WireframeHooks.ConfigStorage = {
  mounted() {
    INFRASTRUCTURE_CONSOLE.log("[ConfigStorage] Hook mounted - loading config from localStorage")

    // Load config from localStorage
    const config = this.loadConfig()

    // Push to LiveView if any config exists
    if (Object.keys(config).length > 0) {
      INFRASTRUCTURE_CONSOLE.log("[ConfigStorage] Loaded config from localStorage:", config)
      this.pushEvent("config_loaded", { config })
    }

    // Listen for save requests from LiveView
    this.handleEvent("save_config", ({ config }) => {
      INFRASTRUCTURE_CONSOLE.log("[ConfigStorage] Saving config to localStorage:", config)
      this.saveConfig(config)
    })

    // Listen for clear requests from LiveView
    this.handleEvent("clear_config", () => {
      INFRASTRUCTURE_CONSOLE.log("[ConfigStorage] Clearing config from localStorage")
      this.clearConfig()
    })
  },

  /**
   * Load config from localStorage
   * Returns empty object if not found or invalid
   */
  loadConfig() {
    try {
      const json = localStorage.getItem('koalemos_config')
      if (!json) return {}

      const config = JSON.parse(json)
      return config || {}
    } catch (error) {
      INFRASTRUCTURE_CONSOLE.error("[ConfigStorage] Failed to load config from localStorage:", error)
      return {}
    }
  },

  /**
   * Save config to localStorage
   * Only saves non-sensitive data (no API keys)
   */
  saveConfig(config) {
    try {
      // Filter out any API keys (safety check - they shouldn't be here)
      const safeConfig = {
        provider: config.provider,
        anthropic_model: config.anthropic_model,
        openai_model: config.openai_model,
        ollama_model: config.ollama_model,
        ollama_base_url: config.ollama_base_url,
        last_updated: new Date().toISOString()
      }

      // Remove undefined/null values
      Object.keys(safeConfig).forEach(key => {
        if (safeConfig[key] === undefined || safeConfig[key] === null) {
          delete safeConfig[key]
        }
      })

      localStorage.setItem('koalemos_config', JSON.stringify(safeConfig))
      INFRASTRUCTURE_CONSOLE.log("[ConfigStorage] Config saved successfully")
    } catch (error) {
      INFRASTRUCTURE_CONSOLE.error("[ConfigStorage] Failed to save config to localStorage:", error)
    }
  },

  /**
   * Clear config from localStorage
   */
  clearConfig() {
    try {
      localStorage.removeItem('koalemos_config')
      INFRASTRUCTURE_CONSOLE.log("[ConfigStorage] Config cleared from localStorage")
    } catch (error) {
      INFRASTRUCTURE_CONSOLE.error("[ConfigStorage] Failed to clear config:", error)
    }
  },

  destroyed() {
    INFRASTRUCTURE_CONSOLE.log("[ConfigStorage] Hook destroyed")
    // No cleanup needed - localStorage persists
  }
}


/**
 * WireframePreview Hook
 *
 * V4 architecture: Direct process communication via Registry, no PubSub.
 *
 * Key differences from V3:
 * - Simpler message flow (direct StateServer communication)
 * - Same JS behavior but cleaner server-side coordination
 *
 * Signal flow:
 * - After init: sends "preview_ready" → server registers with StateServer
 * - On capture_state: sends "state_captured" (DOM + variables)
 * - On execute_interaction: executes action, sends "interaction_complete"
 * - Screenshots are captured server-side via Puppeteer
 *
 * Usage:
 *   <div phx-hook="WireframePreview" id="wireframe-preview">
 */
WireframeHooks.WireframePreview = {
  mounted() {
    INFRASTRUCTURE_CONSOLE.log("[WireframePreview] Hook mounted")

    // Set up console capture
    this.setupConsoleCapture()

    // Listen for capture_state requests from server
    this.handleEvent("capture_state", () => {
      INFRASTRUCTURE_CONSOLE.log("[WireframePreview] Capture state requested")
      this.captureAndSendState()
    })

    // Listen for interaction execution requests
    this.handleEvent("execute_interaction", (args) => {
      INFRASTRUCTURE_CONSOLE.log("[WireframePreview] Execute interaction requested:", args)
      this.executeInteraction(args)
    })

    // Execute after brief delay to ensure DOM is ready
    setTimeout(() => this.executeInitScripts(), 50)
  },

  captureAndSendState() {
    const wireframeData = window.__wireframeDataV4
    const domTree = wireframeData?.domTree
    const rootId = domTree?.id
    const wireframeRoot = rootId ? document.getElementById(rootId) : null

    const runningDom = wireframeRoot ? this.serializeDOM(wireframeRoot) : null

    const variables = {}
    const customVariables = wireframeData?.customVariables || {}
    Object.keys(customVariables).forEach(name => {
      if (name in window) variables[name] = window[name]
    })

    INFRASTRUCTURE_CONSOLE.log("[WireframePreview] Sending captured state, variables:", variables)

    // Send state with keys matching Elixir running state structure
    this.pushEvent("state_captured", {
      dom_tree: runningDom,
      variables: variables,
      console_logs: this.consoleLogs,
      viewport: {
        width: window.innerWidth,
        height: window.innerHeight
      },
      scroll_position: {
        x: window.scrollX || window.pageXOffset || 0,
        y: window.scrollY || window.pageYOffset || 0
      }
    })
  },

  setupConsoleCapture() {
    this.consoleLogs = []

    if (!window.__originalConsole) {
      window.__originalConsole = {
        log: console.log.bind(console),
        warn: console.warn.bind(console),
        error: console.error.bind(console)
      }
    }

    const captureLog = (level, ...args) => {
      window.__originalConsole[level](...args)

      const message = args.map(arg => {
        if (typeof arg === 'string') return arg
        if (arg instanceof Error) return `${arg.name}: ${arg.message}`
        try { return JSON.stringify(arg) } catch(e) { return String(arg) }
      }).join(' ')

      this.consoleLogs.push({ level, message, timestamp: Date.now() })
    }

    console.log = (...args) => captureLog('log', ...args)
    console.warn = (...args) => captureLog('warn', ...args)
    console.error = (...args) => captureLog('error', ...args)
  },

  executeInitScripts() {
    INFRASTRUCTURE_CONSOLE.log("[WireframePreview] Executing init scripts")

    const wireframeData = window.__wireframeDataV4
    INFRASTRUCTURE_CONSOLE.log("[WireframePreview] wireframeData:", wireframeData)

    if (!wireframeData) {
      INFRASTRUCTURE_CONSOLE.warn("[WireframePreview] No wireframe data found")
      this.sendPreviewReady()
      return
    }

    // Set up custom variables
    const customVariables = wireframeData.customVariables || {}
    INFRASTRUCTURE_CONSOLE.log("[WireframePreview] customVariables:", customVariables)
    Object.entries(customVariables).forEach(([name, value]) => {
      window[name] = value
      INFRASTRUCTURE_CONSOLE.log(`[WireframePreview] Set variable: ${name}`)
    })

    // Execute init scripts
    const initScripts = wireframeData.initScripts || {}
    INFRASTRUCTURE_CONSOLE.log("[WireframePreview] initScripts:", initScripts)
    const scriptNames = Object.keys(initScripts).sort()

    INFRASTRUCTURE_CONSOLE.log(`[WireframePreview] Executing ${scriptNames.length} init scripts`)

    scriptNames.forEach(name => {
      const code = initScripts[name]
      try {
        INFRASTRUCTURE_CONSOLE.log(`[WireframePreview] Executing: ${name}`)
        window.eval(code)
      } catch (error) {
        INFRASTRUCTURE_CONSOLE.error(`[WireframePreview] Script '${name}' failed:`, error)
        console.error(`Init script '${name}' error: ${error.message}`)
      }
    })

    // Attach handlers
    this.attachHandlers(wireframeData.handlers || {})

    // Brief delay then send preview_ready
    setTimeout(() => this.sendPreviewReady(), 100)
  },

  attachHandlers(handlers) {
    INFRASTRUCTURE_CONSOLE.log("[WireframePreview] Attaching handlers:", Object.keys(handlers))

    Object.entries(handlers).forEach(([elementId, events]) => {
      const element = document.getElementById(elementId)
      if (!element) {
        INFRASTRUCTURE_CONSOLE.warn(`[WireframePreview] Element not found: ${elementId}`)
        return
      }

      Object.entries(events).forEach(([eventName, handlerData]) => {
        try {
          const code = typeof handlerData === 'string' ? handlerData : handlerData.body
          const handlerFunc = new Function('event', code)

          element.addEventListener(eventName, (event) => {
            INFRASTRUCTURE_CONSOLE.log(`[WireframePreview] Handler: ${elementId}.${eventName}`)
            handlerFunc.call(element, event)
          })

          INFRASTRUCTURE_CONSOLE.log(`[WireframePreview] Attached ${eventName} to ${elementId}`)
        } catch (error) {
          INFRASTRUCTURE_CONSOLE.error(`[WireframePreview] Handler attach failed:`, error)
        }
      })
    })
  },

  sendPreviewReady() {
    // Signal that preview is ready - server will register us with StateServer
    INFRASTRUCTURE_CONSOLE.log("[WireframePreview] Sending preview_ready")
    this.pushEvent("preview_ready", {})
  },

  executeInteraction(command) {
    INFRASTRUCTURE_CONSOLE.log("[WireframePreview] Executing interaction:", command)

    try {
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
          this.executeJavaScript(command.js_code || command.value)
          break
        default:
          throw new Error(`Unknown interaction action: ${command.action}`)
      }

      // Wait for DOM changes to settle, then notify completion
      setTimeout(() => {
        this.pushEvent("interaction_complete", {
          success: true,
          action: command.action
        })
      }, 300)

    } catch (error) {
      INFRASTRUCTURE_CONSOLE.error("[WireframePreview] Interaction failed:", error)
      this.pushEvent("interaction_complete", {
        success: false,
        action: command.action,
        error: error.message
      })
    }
  },

  triggerClick(elementId) {
    const el = document.getElementById(elementId)
    if (!el) throw new Error(`Element not found: ${elementId}`)
    INFRASTRUCTURE_CONSOLE.log(`[WireframePreview] Clicking: ${elementId}`)
    el.click()
  },

  fillInput(elementId, value) {
    const el = document.getElementById(elementId)
    if (!el) throw new Error(`Element not found: ${elementId}`)
    INFRASTRUCTURE_CONSOLE.log(`[WireframePreview] Filling ${elementId} with: ${value}`)
    el.value = value
    el.dispatchEvent(new Event('input', { bubbles: true }))
    el.dispatchEvent(new Event('change', { bubbles: true }))
  },

  submitForm(elementId) {
    const el = document.getElementById(elementId)
    if (!el) throw new Error(`Element not found: ${elementId}`)
    INFRASTRUCTURE_CONSOLE.log(`[WireframePreview] Submitting form: ${elementId}`)
    el.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
  },

  executeJavaScript(code) {
    INFRASTRUCTURE_CONSOLE.log(`[WireframePreview] Executing JS: ${code?.substring(0, 50)}...`)
    const func = new Function(code)
    func()
  },

  serializeDOM(element) {
    if (!element || element.nodeType !== 1) return null
    if (element.tagName === 'SCRIPT' || element.tagName === 'STYLE') return null

    const attributes = {}
    Array.from(element.attributes).forEach(attr => {
      if (attr.name !== 'id' && attr.name !== 'class') {
        attributes[attr.name] = attr.value
      }
    })

    // For canvas elements, capture current pixel content
    // This allows screenshots to show canvas drawings
    if (element.tagName === 'CANVAS') {
      try {
        const dataURL = element.toDataURL('image/png')
        attributes['data-canvas-snapshot'] = dataURL
        const sizeKB = Math.round(dataURL.length / 1024)
        INFRASTRUCTURE_CONSOLE.log(`[WireframePreview] Captured canvas ${element.id || '(no id)'}: ${sizeKB}KB`)
      } catch (error) {
        INFRASTRUCTURE_CONSOLE.warn(`[WireframePreview] Failed to capture canvas ${element.id || '(no id)'}:`, error.message)
        attributes['data-canvas-error'] = error.message
      }
    }

    let content = null
    if (element.children.length === 0) {
      content = element.textContent?.trim() || null
    }

    const children = []
    Array.from(element.children).forEach(child => {
      const serialized = this.serializeDOM(child)
      if (serialized) children.push(serialized)
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

  destroyed() {
    INFRASTRUCTURE_CONSOLE.log("[WireframePreview] Hook destroyed")
    if (window.__originalConsole) {
      console.log = window.__originalConsole.log
      console.warn = window.__originalConsole.warn
      console.error = window.__originalConsole.error
    }
  }
}

export default WireframeHooks
