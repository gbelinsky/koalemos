# Core Koalemos engine - development configuration

import Config

# Event logging configuration (for debugging)
config :koalemos,
  # Enable event logging in development
  enable_event_logging: true,
  # Write to tmp directory (not included in releases)
  event_log_path: "tmp/events.log"
