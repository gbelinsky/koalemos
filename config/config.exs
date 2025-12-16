# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :koalemos,
  generators: [timestamp_type: :utc_datetime]

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
  koalemos: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --log-override:direct-eval=silent),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ],
  preview: [
    args:
      ~w(js/preview.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/* --log-override:direct-eval=silent),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  koalemos: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
