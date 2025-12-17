// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// LiveView Hooks
const Hooks = {}

// Auto-scroll messages to bottom when new messages arrive
Hooks.ScrollToBottom = {
  mounted() {
    // Always scroll to bottom on initial load
    this.scrollToBottom()
    this.setupScrollButton()
  },
  updated() {
    const container = this.el.closest('.overflow-y-auto')
    if (!container) return

    // Check if user was at bottom BEFORE the update
    // (we track this from scroll events)
    if (this.wasAtBottom !== false) {  // Default to true on first update
      this.scrollToBottom()
      this.hideScrollButton()
    } else {
      // User scrolled up - show button to jump to bottom
      this.showScrollButton()
    }
  },
  setupScrollButton() {
    const container = this.el.closest('.overflow-y-auto')
    if (!container) return

    // Track scroll position to know if user scrolled up
    container.addEventListener('scroll', () => {
      this.wasAtBottom = this.isAtBottom(container)
      if (this.wasAtBottom) {
        this.hideScrollButton()
      }
    })

    // Create scroll-to-bottom button
    this.scrollBtn = document.createElement('button')
    this.scrollBtn.className = 'fixed bottom-24 right-8 bg-indigo-600 text-white px-4 py-2 rounded-full shadow-lg hover:bg-indigo-700 transition-all z-10 hidden items-center space-x-2'
    this.scrollBtn.innerHTML = '<span>New messages</span><span>↓</span>'
    this.scrollBtn.onclick = () => {
      this.scrollToBottom()
      this.wasAtBottom = true
      this.hideScrollButton()
    }
    container.parentElement.appendChild(this.scrollBtn)
  },
  showScrollButton() {
    if (this.scrollBtn) {
      this.scrollBtn.classList.remove('hidden')
      this.scrollBtn.classList.add('flex')
    }
  },
  hideScrollButton() {
    if (this.scrollBtn) {
      this.scrollBtn.classList.add('hidden')
      this.scrollBtn.classList.remove('flex')
    }
  },
  isAtBottom(container) {
    // Consider "at bottom" if within 100px of bottom (allows for some slack)
    const threshold = 100
    return container.scrollHeight - container.scrollTop - container.clientHeight < threshold
  },
  scrollToBottom() {
    // Find the scrollable parent container
    const container = this.el.closest('.overflow-y-auto')
    if (container) {
      container.scrollTop = container.scrollHeight
    }
  },
  destroyed() {
    // Clean up button when component is destroyed
    if (this.scrollBtn && this.scrollBtn.parentElement) {
      this.scrollBtn.parentElement.removeChild(this.scrollBtn)
    }
  }
}

// Auto-focus input field on page load and handle Enter key submit
Hooks.AutoFocus = {
  mounted() {
    // Focus the element after a brief delay to ensure LiveView is ready
    setTimeout(() => this.el.focus(), 100)

    this.handleKeyDown = (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        // Enter without Shift: prevent newline and trigger submit
        e.preventDefault()

        // Get the send button ID from the textarea ID (textarea is "id-textarea", button is "id-send-button")
        const textareaId = this.el.id
        const buttonId = textareaId.replace('-textarea', '-send-button')
        const sendButton = document.getElementById(buttonId)

        if (sendButton && !sendButton.disabled) {
          sendButton.click()
        }
      }
      // Shift+Enter: do nothing, allow default newline
    }

    this.el.addEventListener('keydown', this.handleKeyDown)
  },

  destroyed() {
    if (this.handleKeyDown) {
      this.el.removeEventListener('keydown', this.handleKeyDown)
    }
  }
}

// Panel resizer hook for adjustable dividers
Hooks.PanelResizer = {
  mounted() {
    let isDragging = false
    let container = null
    let overlay = null

    this.el.addEventListener('mousedown', (e) => {
      isDragging = true
      container = document.getElementById('resizable-container')

      // Create overlay to prevent iframe from capturing events
      overlay = document.createElement('div')
      overlay.style.position = 'fixed'
      overlay.style.top = '0'
      overlay.style.left = '0'
      overlay.style.width = '100%'
      overlay.style.height = '100%'
      overlay.style.zIndex = '9999'
      overlay.style.cursor = 'col-resize'
      document.body.appendChild(overlay)

      document.body.style.cursor = 'col-resize'
      document.body.style.userSelect = 'none'
      e.preventDefault()
    })

    document.addEventListener('mousemove', (e) => {
      if (!isDragging || !container) return

      const containerRect = container.getBoundingClientRect()
      const newWidth = ((e.clientX - containerRect.left) / containerRect.width) * 100

      // Clamp between 20% and 60%
      const clampedWidth = Math.max(20, Math.min(60, Math.round(newWidth)))

      // Send to server
      this.pushEvent("resize_panel", { width: clampedWidth.toString() })
    })

    document.addEventListener('mouseup', () => {
      if (isDragging) {
        isDragging = false
        document.body.style.cursor = ''
        document.body.style.userSelect = ''

        // Remove overlay
        if (overlay && overlay.parentNode) {
          overlay.parentNode.removeChild(overlay)
          overlay = null
        }
      }
    })
  }
}

// Import wireframe-specific hooks (M3 Sprint 2)
import WireframeHooks from "./wireframe_hooks.js"

// Merge wireframe hooks into global hooks
// These hooks only activate on elements with phx-hook="HookName"
Object.assign(Hooks, WireframeHooks)

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Handle download events from LiveView (blob download - works via localhost or HTTPS)
window.addEventListener("phx:download", (e) => {
  const { filename, content, mime_type } = e.detail
  const blob = new Blob([content], { type: mime_type })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
})

// Handle clear-input events from LiveView
window.addEventListener("phx:clear-input", (event) => {
  const { id } = event.detail
  const input = document.getElementById(id)
  if (input) {
    input.value = ''
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

