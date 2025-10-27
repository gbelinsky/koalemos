defmodule Koalemos.Steps.System.Config do
  @moduledoc """
  Config step injects literal configuration values into the routine context.

  This step acts as a simple pass-through that adds its config directly to the
  routine context, allowing subsequent steps to read their configuration from
  context instead of having it duplicated across multiple step configs.

  Config goes in, context comes out. Simple and clean.

  ## Usage

  ```elixir
  start: %{
    type: Koalemos.Steps.System.Config,
    config: %{
      provider: :anthropic,
      source: :env,
      lenses: [{Koalemos.Lenses.Notes, []}],
      llm_model: "claude-sonnet-4-20250514"
    },
    transitions: [{:next_step, :always}]
  }
  ```

  After execution, the context will contain all the config values:
  - context.provider = :anthropic
  - context.source = :env
  - context.lenses = [{Koalemos.Lenses.Notes, []}]
  - context.llm_model = "claude-sonnet-4-20250514"
  """

  def execute(config, _state) do
    # Simply add all config values to context
    {:ok, [add_or_update: config]}
  end
end
