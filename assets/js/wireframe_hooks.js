// Wireframe Editor LiveView hooks
// Editor-only hooks - preview uses separate preview.js bundle

const WireframeHooks = {}

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
    console.log("[ConfigStorage] Hook mounted - loading config from localStorage")

    // Load config from localStorage
    const config = this.loadConfig()

    // Push to LiveView if any config exists
    if (Object.keys(config).length > 0) {
      console.log("[ConfigStorage] Loaded config from localStorage:", config)
      this.pushEvent("config_loaded", { config })
    }

    // Listen for save requests from LiveView
    this.handleEvent("save_config", ({ config }) => {
      console.log("[ConfigStorage] Saving config to localStorage:", config)
      this.saveConfig(config)
    })

    // Listen for clear requests from LiveView
    this.handleEvent("clear_config", () => {
      console.log("[ConfigStorage] Clearing config from localStorage")
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
      console.error("[ConfigStorage] Failed to load config from localStorage:", error)
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
      console.log("[ConfigStorage] Config saved successfully")
    } catch (error) {
      console.error("[ConfigStorage] Failed to save config to localStorage:", error)
    }
  },

  /**
   * Clear config from localStorage
   */
  clearConfig() {
    try {
      localStorage.removeItem('koalemos_config')
      console.log("[ConfigStorage] Config cleared from localStorage")
    } catch (error) {
      console.error("[ConfigStorage] Failed to clear config:", error)
    }
  },

  destroyed() {
    console.log("[ConfigStorage] Hook destroyed")
    // No cleanup needed - localStorage persists
  }
}

export default WireframeHooks
