defmodule KoalemosInspectorWeb.Supervisor do
  @moduledoc """
  Defines the KoalemosInspectorWeb supervision children.
  """

  @doc """
  Returns the list of child specs for the inspector web application.
  """
  def children do
    [
      KoalemosInspectorWeb.Endpoint
    ]
  end
end
