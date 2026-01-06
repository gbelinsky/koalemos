import Config

# Import component-specific production configuration
import_config "koalemos_core.prod.exs"
import_config "wireframe_editor_web.prod.exs"

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
