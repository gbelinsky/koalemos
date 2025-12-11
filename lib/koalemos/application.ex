defmodule Koalemos.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Base children list
    children = [
      KoalemosWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:koalemos, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Koalemos.PubSub},
      # Routine Registry - for looking up Engine processes by routine_id
      {Registry, keys: :unique, name: Koalemos.RoutineRegistry},
      # WireframeStateServer Registry - for state servers (direct communication)
      {Registry, keys: :unique, name: Koalemos.WireframeRegistry},
      # WireframeStateServer Supervisor - manages state servers per routine
      {DynamicSupervisor, strategy: :one_for_one, name: KoalemosWeb.Supervisors.WireframeStateServerSupervisor},
      # Observer - for recording routine events
      Koalemos.Engine.Observer,
      # Cache GenServers - for storing wireframe runtime state
      # Screenshot images
      Koalemos.Caches.ScreenshotCache,
      # Live DOM trees
      Koalemos.Caches.DOMStateCache,
      # Console messages with rate limiting
      Koalemos.Caches.ConsoleCache,
      # Runtime variable values
      Koalemos.Caches.VariableStateCache,
      # Lens state for wireframe preview
      Koalemos.Caches.WireframeStateCache,
      # NodeJS Supervisor - for JavaScript parsing
      {NodeJS.Supervisor, [path: Path.join([:code.priv_dir(:koalemos), "nodejs"]), pool_size: 4]},
      # Credential manager
      Koalemos.SimpleCredentialManager,
      # Web endpoint
      KoalemosWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Koalemos.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KoalemosWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
