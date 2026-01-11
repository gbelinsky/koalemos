# KoalemosInspectorWeb - development configuration

import Config

# For development, we run on port 4001
config :koalemos, KoalemosInspectorWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4001],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "InspectorDevSecretKeyBase1234567890123456789012345678901234567890"

# Watch static and templates for browser reloading
config :koalemos, KoalemosInspectorWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/koalemos_inspector_web/(live|components)/.*(ex|heex)$"
    ]
  ]
