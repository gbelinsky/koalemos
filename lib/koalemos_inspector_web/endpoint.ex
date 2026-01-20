defmodule KoalemosInspectorWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :koalemos

  @session_options [
    store: :cookie,
    key: "_koalemos_inspector_key",
    signing_salt: "Inspector7x",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Serve static files from the same priv/static as the main app
  plug Plug.Static,
    at: "/",
    from: :koalemos,
    gzip: false,
    only: KoalemosInspectorWeb.static_paths()

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug KoalemosInspectorWeb.Router
end
