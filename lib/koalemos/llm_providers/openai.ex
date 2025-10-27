defmodule Koalemos.LLMProviders.OpenAI do
  @moduledoc """
  OpenAI API provider (STUB).

  This is a placeholder stub that will be implemented in Phase 6d-5.

  Implementation will include:
  - Message format conversion (Anthropic → OpenAI)
  - Tool schema conversion (Anthropic → OpenAI)
  - System message as first message in array
  - API key authentication
  """

  @behaviour Koalemos.LLMProvider

  @impl true
  def call(_messages, _credentials, _tool_descriptions, _lens_contexts, _config, _routine_id) do
    {:error, "OpenAI provider not yet implemented (Phase 6d-5)"}
  end
end
