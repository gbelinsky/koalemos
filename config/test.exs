import Config

# Import component-specific test configuration
import_config "koalemos_core.test.exs"
import_config "wireframe_editor_web.test.exs"

# Print only warnings and errors during test
config :logger, level: :warning
