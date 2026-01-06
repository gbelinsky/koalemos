# Core Koalemos engine configuration
# This file contains configuration for the core processing engine,
# separate from the web UI layer.

import Config

config :koalemos,
  generators: [timestamp_type: :utc_datetime]
