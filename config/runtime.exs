import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/koalemos start
#
# For Koalemos, we default to starting the server since it's a web application.
# Set PHX_SERVER=false to disable if needed (e.g., for running migrations only).
unless System.get_env("PHX_SERVER") == "false" do
  config :koalemos, WireframeEditorWeb.Endpoint, server: true
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # For Koalemos (a local application), we auto-generate and persist a secret
  # on first run, so users don't have to manage it manually.
  #
  # Priority:
  # 1. SECRET_KEY_BASE env var (if set - allows manual override)
  # 2. Persisted secret at ~/.koalemos/secret_key_base (auto-generated on first run)

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      (
        secret_file = Path.join(System.user_home!(), ".koalemos/secret_key_base")

        if File.exists?(secret_file) do
          # Load existing secret
          File.read!(secret_file) |> String.trim()
        else
          # Generate new secret and save it
          IO.puts("[Koalemos] Generating new SECRET_KEY_BASE at #{secret_file}")
          secret = :crypto.strong_rand_bytes(64) |> Base.encode64(padding: false)
          File.mkdir_p!(Path.dirname(secret_file))
          File.write!(secret_file, secret)
          File.chmod!(secret_file, 0o600)  # Read/write for owner only
          IO.puts("[Koalemos] Secret generated and saved")
          secret
        end
      )

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :koalemos, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :koalemos, WireframeEditorWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    # Disable origin checking for local development tool (allow access from any machine)
    check_origin: false

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :koalemos, WireframeEditorWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :koalemos, WireframeEditorWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
