import Config

# Import component-specific development configuration
import_config "koalemos_core.dev.exs"
import_config "wireframe_editor_web.dev.exs"

# Development log format with source location for domain logs
# Domain logs will show: [level] message file=foo.ex line=42 domain=context
# truncate: :infinity allows full context logging without truncation
config :logger, :console,
  format: "[$level] $message $metadata\n",
  metadata: [:file, :line, :domain],
  truncate: :infinity
