defmodule Koalemos.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Shared infrastructure
    infrastructure = [
      {DNSCluster, query: Application.get_env(:koalemos, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Koalemos.PubSub}
    ]

    # Compose children from each domain
    children =
      infrastructure ++
        Koalemos.Supervisor.children() ++
        WireframeEditorWeb.Supervisor.children()

    opts = [strategy: :one_for_one, name: Koalemos.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    WireframeEditorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
