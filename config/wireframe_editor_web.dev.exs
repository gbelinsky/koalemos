# WireframeEditorWeb UI - development configuration

import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :koalemos, WireframeEditorWeb.Endpoint,
  # Binding to all interfaces to allow access from other machines
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "TSVU2CTMxNSqfZ+4idU0J0qHIa2pOhIrDMHqFBdqDjHqnXeTXMHp7YEJWGXZiY5F",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:ui_wireframe_editor, ~w(--sourcemap=inline --watch)]},
    esbuild_preview: {Esbuild, :install_and_run, [:ui_wireframe_editor_preview, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:ui_wireframe_editor, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :koalemos, WireframeEditorWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/wireframe_editor_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :koalemos, dev_routes: true

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true
