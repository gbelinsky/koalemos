# WireframeEditorWeb UI configuration
# This file contains configuration for the wireframe editor web interface,
# designed as a pluggable UI that can be extended or replaced.

import Config

# Configures the endpoint
config :koalemos, WireframeEditorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: WireframeEditorWeb.ErrorHTML, json: WireframeEditorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Koalemos.PubSub,
  live_view: [signing_salt: "dYOj9otK"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  ui_wireframe_editor: [
    args:
      ~w(js/wireframe_editor.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --log-override:direct-eval=silent),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  ui_wireframe_editor_preview: [
    args:
      ~w(js/preview.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --log-override:direct-eval=silent),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  ui_wireframe_editor: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/wireframe_editor.css
      --output=../priv/static/assets/wireframe_editor.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Filter sensitive parameters from logs in all environments
config :phoenix, :filter_parameters, [
  "password",
  "api_key",
  "secret",
  "token",
  "refresh_token",
  "access_token"
]
