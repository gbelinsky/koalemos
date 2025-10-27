defmodule Koalemos.LLMProvider do
  @moduledoc """
  Behavior for LLM provider plugins.

  Defines the interface that all LLM providers (Anthropic, OpenAI, Ollama)
  must implement. Each provider is responsible for its own message formatting,
  authentication, HTTP requests, and error handling.

  ## Provider Responsibilities

  - **Message formatting**: Convert internal message format to provider-specific format
  - **System prompts**: Build system message/content in provider-specific way
  - **Authentication**: Build appropriate auth headers (API key, OAuth, Bearer, etc.)
  - **HTTP requests**: Make API calls with retry logic
  - **Tool schemas**: Convert or use tool descriptions as needed
  - **Error handling**: Handle provider-specific errors and retries

  ## Callback

  `call/6` takes:
  - `messages` - List of conversation messages in internal format
  - `credentials` - Map with provider credentials (from DemoCredentialStore/SimpleCredentialManager)
  - `tool_descriptions` - List of tool schemas (from ToolSchema step)
  - `lens_contexts` - List of lens context blocks (from LensRendering step)
  - `config` - Map with runtime configuration (model, max_tokens, temperature, etc.)
  - `routine_id` - Routine ID for logging/tracking

  Returns:
  - `{:ok, context_diff}` - Context diff with `:llm_response` key
  - `{:error, reason}` - Error message (string or atom)

  ## Example Implementation

  ```elixir
  defmodule Koalemos.LLMProviders.Example do
    @behaviour Koalemos.LLMProvider

    @impl true
    def call(messages, credentials, tool_descriptions, lens_contexts, config, routine_id) do
      # 1. Format messages for provider
      # 2. Build system prompt
      # 3. Construct request body
      # 4. Make HTTP request
      # 5. Handle errors and retries
      # 6. Return {:ok, [add_or_update: %{llm_response: response}]}
    end
  end
  ```

  ## See Also

  - `Koalemos.LLMProvider.Utils` - Common message utilities
  - `Koalemos.Steps.Agent.LLMRequest` - Router step that uses providers
  - `docs/LLM_PROVIDER_GUIDE.md` - Detailed implementation guide
  """

  @doc """
  Make an LLM API request and return the response.

  ## Parameters

  - `messages` - Conversation history in internal format
  - `credentials` - Provider credentials map
  - `tool_descriptions` - Available tool schemas
  - `lens_contexts` - Lens context blocks for system prompt
  - `config` - Runtime configuration (model, max_tokens, etc.)
  - `routine_id` - Routine ID for logging

  ## Returns

  - `{:ok, context_diff}` - Diff with `llm_response` in `add_or_update`
  - `{:error, reason}` - Error string or atom
  """
  @callback call(
              messages :: list(),
              credentials :: map(),
              tool_descriptions :: list(),
              lens_contexts :: list(),
              config :: map(),
              routine_id :: String.t()
            ) :: {:ok, Keyword.t()} | {:error, String.t() | atom()}
end
