import Config

# Import component-specific development configuration
import_config "koalemos_core.dev.exs"
import_config "wireframe_editor_web.dev.exs"

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
