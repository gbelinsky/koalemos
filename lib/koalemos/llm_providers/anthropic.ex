defmodule Koalemos.LLMProviders.Anthropic do
  @moduledoc """
  Anthropic Claude API provider (STUB).

  This is a placeholder stub that will be implemented in Phase 6d-4.

  Implementation will include:
  - Native Anthropic message format
  - API key and OAuth authentication
  - Progressive retry logic (45s, 90s, 180s timeouts)
  - System content as array of blocks
  """

  @behaviour Koalemos.LLMProvider

  @impl true
  def call(_messages, _credentials, _tool_descriptions, _lens_contexts, _config, _routine_id) do
    {:error, "Anthropic provider not yet implemented (Phase 6d-4)"}
  end
end
