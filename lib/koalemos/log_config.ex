defmodule Koalemos.LogConfig do
  @moduledoc """
  Runtime-configurable logging by domain.

  Allows enabling/disabling log output for specific domains at runtime,
  useful for debugging specific parts of the system without drowning in logs.

  ## Available Domains

  - `:llm` - LLM provider requests and responses
  - `:context` - Context building in provide_context
  - `:prompts` - Complete system prompts sent to LLM
  - `:engine` - Engine orchestration and step execution
  - `:wireframe` - Wireframe editor operations
  - `:lens` - Lens tool execution
  - `:all` - Enable all domains

  ## Usage

  ```elixir
  # Enable a domain
  Koalemos.LogConfig.enable(:context)

  # Disable a domain
  Koalemos.LogConfig.disable(:context)

  # Check if enabled
  Koalemos.LogConfig.enabled?(:context)

  # List enabled domains
  Koalemos.LogConfig.list()

  # Enable all domains
  Koalemos.LogConfig.enable(:all)

  # Disable all domains
  Koalemos.LogConfig.disable_all()
  ```

  ## Connecting to a Running Server

  ```bash
  # Start with a name
  iex --sname debug --remsh koalemos@hostname

  # Then enable domains
  Koalemos.LogConfig.enable(:context)
  ```
  """

  use Agent

  @doc "Start the LogConfig agent"
  def start_link(_opts) do
    Agent.start_link(fn -> MapSet.new() end, name: __MODULE__)
  end

  @doc "Enable logging for a domain"
  def enable(domain) when is_atom(domain) do
    Agent.update(__MODULE__, &MapSet.put(&1, domain))
    :ok
  end

  @doc "Disable logging for a domain"
  def disable(domain) when is_atom(domain) do
    Agent.update(__MODULE__, &MapSet.delete(&1, domain))
    :ok
  end

  @doc "Disable all logging domains"
  def disable_all do
    Agent.update(__MODULE__, fn _ -> MapSet.new() end)
    :ok
  end

  @doc "Check if a domain is enabled"
  def enabled?(domain) when is_atom(domain) do
    Agent.get(__MODULE__, fn domains ->
      MapSet.member?(domains, :all) || MapSet.member?(domains, domain)
    end)
  end

  @doc "List all enabled domains"
  def list do
    Agent.get(__MODULE__, &MapSet.to_list/1)
  end

  @doc false
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end
end
