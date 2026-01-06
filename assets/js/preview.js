// Minimal LiveView bundle for wireframe preview iframe
// Only includes the WireframePreview hook - no editor functionality

import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

// Infrastructure console - never captured, only shows in browser
// Uses the original console methods saved by early interception script
const INFRASTRUCTURE_CONSOLE = {
  log: function(...args) {
    if (window.__originalConsole?.log) {
      window.__originalConsole.log(...args)
    } else {
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

const Hooks = {}

/**
 * WireframePreview Hook
 *
 * V4 architecture: Direct process communication via Registry, no PubSub.
 *
 * Signal flow:
 * - After init: sends "preview_ready" → server registers with StateServer
 * - On capture_state: sends "state_captured" (DOM + variables)
 * - On execute_interaction: executes action, sends "interaction_complete"
 * - Screenshots are captured server-side via Puppeteer
 */
Hooks.WireframePreview = {
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

      // Filter out Phoenix LiveView debug messages (phx-* element updates)
      if (message.startsWith('phx-')) return

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
          let code, params
          if (typeof handlerData === 'string') {
            code = handlerData
            params = ['e']  // Default parameter name
          } else {
            code = handlerData.body
            params = handlerData.params || ['e']
          }

          // Create function with the specified parameter names
          const handlerFunc = new Function(...params, code)

          element.addEventListener(eventName, (e) => {
            INFRASTRUCTURE_CONSOLE.log(`[WireframePreview] Handler: ${elementId}.${eventName}`)
            handlerFunc.call(element, e)
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
          this.executeJavaScript(command.javascript || command.js_code || command.value)
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

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Connect to LiveView
liveSocket.connect()

// Expose for debugging
window.liveSocket = liveSocket
