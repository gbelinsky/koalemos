# KoalemosInspectorWeb - base configuration

import Config

# Configures the endpoint
config :koalemos, KoalemosInspectorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: KoalemosInspectorWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: Koalemos.PubSub,
  live_view: [signing_salt: "InspectorSalt"]
