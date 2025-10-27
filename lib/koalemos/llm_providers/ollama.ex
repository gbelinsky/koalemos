defmodule Koalemos.LLMProviders.Ollama do
  @moduledoc """
  Ollama local LLM provider (STUB).

  This is a placeholder stub that will be implemented in Phase 6d-6.

  Implementation will include:
  - Same message format as OpenAI (reuses conversion logic)
  - Local endpoint (http://localhost:11434)
  - No authentication required
  """

  @behaviour Koalemos.LLMProvider

  @impl true
  def call(_messages, _credentials, _tool_descriptions, _lens_contexts, _config, _routine_id) do
    {:error, "Ollama provider not yet implemented (Phase 6d-6)"}
  end
end
