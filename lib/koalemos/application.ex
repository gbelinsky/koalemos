defmodule Koalemos.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      KoalemosWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:koalemos, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Koalemos.PubSub},
      # Routine Registry - for looking up Engine processes by routine_id
      {Registry, keys: :unique, name: Koalemos.RoutineRegistry},
      # Observer - for recording routine events
      Koalemos.Engine.Observer,
      # Start a worker by calling: Koalemos.Worker.start_link(arg)
      # {Koalemos.Worker, arg},
      # Start to serve requests, typically the last entry
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
