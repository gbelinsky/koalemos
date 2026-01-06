defmodule WireframeEditorWeb.Supervisor do
  @moduledoc """
  Defines the WireframeEditorWeb supervision children.

  This module is used by the application to compose supervision trees,
  making it easier to separate web from core in the future.
  """

  @doc """
  Returns the list of child specs for the web application.
  """
  def children do
    [
      WireframeEditorWeb.Telemetry,
      # WireframeStateServer Registry - for state servers (direct communication)
      {Registry, keys: :unique, name: Koalemos.WireframeRegistry},
      # WireframeStateServer Supervisor - manages state servers per routine
      {DynamicSupervisor,
       strategy: :one_for_one, name: WireframeEditorWeb.Supervisors.WireframeStateServerSupervisor},
      # NodeJS Supervisor - for JavaScript/CSS parsing
      {NodeJS.Supervisor, [path: nodejs_path(), pool_size: 4]},
      # Web endpoint
      WireframeEditorWeb.Endpoint
    ]
  end

  defp nodejs_path do
    Path.join([:code.priv_dir(:koalemos), "nodejs"])
  end
end
