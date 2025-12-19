defmodule Koalemos.Supervisor do
  @moduledoc """
  Defines the core Koalemos engine supervision children.

  This module is used by the application to compose supervision trees,
  making it easier to separate core from web in the future.
  """

  @doc """
  Returns the list of child specs for the core engine.
  """
  def children do
    [
      # Routine Registry - for looking up Engine processes by routine_id
      {Registry, keys: :unique, name: Koalemos.RoutineRegistry},
      # Observer - for recording routine events
      Koalemos.Engine.Observer,
      # Credential manager
      Koalemos.SimpleCredentialManager
    ]
  end
end
