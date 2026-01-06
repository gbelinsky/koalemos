# LLM Provider Plugin Guide

This guide explains how to create a new LLM provider plugin for Koalemos.

## Overview

Koalemos uses a plugin architecture for LLM providers. Each provider implements the `Koalemos.LLMProvider` behavior and handles provider-specific details like:

- Message format conversion
- Authentication (API keys)
- HTTP request construction
- Response parsing
- Error handling
- Retry logic

The `Koalemos.Steps.Agent.LLMRequest` step acts as a router that delegates to the appropriate provider based on context.

## Plugin Architecture

```
┌─────────────────────────────────────┐
│   LLMRequest Router Step            │
│   - Provider resolution             │
│   - Credential resolution           │
│   - Delegates to provider module    │
└──────────┬──────────────────────────┘
           │
           ├──> Anthropic Provider
           ├──> OpenAI Provider
           └──> Ollama Provider
```

## Creating a New Provider

### Step 1: Implement the Behavior

Create a new module in `lib/koalemos/llm_providers/` that implements `Koalemos.LLMProvider`:

```elixir
defmodule Koalemos.LLMProviders.YourProvider do
  @moduledoc """
  YourProvider API integration.
  """

  @behaviour Koalemos.LLMProvider

  require Logger

  @impl true
  def call(messages, credentials, tool_descriptions, lens_contexts, config, routine_id) do
    # Implementation here
  end
end
```

### Step 2: Handle Messages

The `messages` parameter contains the conversation history in Anthropic format:

```elixir
[
  %{
    role: "user",
    content: [
      %{type: "text", text: "Hello!"}
    ]
  },
  %{
    role: "assistant",
    content: [
      %{type: "text", text: "Hi there!"}
    ]
  }
]
```

Use `Koalemos.LLMProvider.Utils` for common transformations:

```elixir
alias Koalemos.LLMProvider.Utils

# Strip internal metadata before sending to API
clean_messages = Enum.map(messages, &Utils.strip_metadata/1)

# Filter out empty assistant messages
filtered = Utils.filter_empty_assistant_messages(clean_messages)

# Keep only last screenshot for token optimization
optimized = Utils.keep_only_last_screenshot(filtered)
```

If your provider uses a different message format (e.g., OpenAI), convert the messages:

```elixir
defp convert_to_openai_format(messages) do
  # Convert from Anthropic format to OpenAI format
  # - Extract system messages
  # - Flatten content arrays to strings
  # - Handle tool calls differently
end
```

### Step 3: Handle Tools

The `tool_descriptions` parameter contains tool schemas in Anthropic format. Convert if needed:

```elixir
defp convert_tools(tool_descriptions) do
  Enum.map(tool_descriptions, fn tool ->
    %{
      type: "function",
      function: %{
        name: tool.name,
        description: tool.description,
        parameters: tool.input_schema
      }
    }
  end)
end
```

### Step 4: Handle Credentials

The `credentials` map contains authentication info:

```elixir
%{
  provider: :your_provider,
  api_key: "sk-...",
  base_url: "https://api.yourprovider.com/v1",
  auth_type: :api_key
}
```

### Step 5: Handle Configuration

The `config` map contains request parameters:

```elixir
%{
  model: "your-model-name",      # May be nil, use default
  max_tokens: 16384,             # Default: 16384
  temperature: 0.1,              # Default: 0.1
  base_url: nil                  # Optional override
}
```

### Step 6: Make the HTTP Request

Use HTTPoison or Req to make the API request:

```elixir
defp make_request(messages, credentials, tools, config) do
  url = "#{credentials.base_url}/messages"

  headers = [
    {"Content-Type", "application/json"},
    {"Authorization", "Bearer #{credentials.api_key}"}
  ]

  body = Jason.encode!(%{
    model: config.model || "default-model",
    messages: messages,
    tools: tools,
    max_tokens: config.max_tokens,
    temperature: config.temperature
  })

  case HTTPoison.post(url, body, headers, timeout: 45_000) do
    {:ok, %{status_code: 200, body: response_body}} ->
      parse_response(response_body)

    {:ok, %{status_code: status, body: error_body}} ->
      {:error, "API error #{status}: #{error_body}"}

    {:error, %HTTPoison.Error{reason: reason}} ->
      {:error, "HTTP error: #{inspect(reason)}"}
  end
end
```

### Step 7: Parse the Response

Return a keyword list with the raw response:

```elixir
defp parse_response(body) do
  case Jason.decode(body) do
    {:ok, response} ->
      {:ok, [llm_response: response]}

    {:error, reason} ->
      {:error, "JSON parse error: #{inspect(reason)}"}
  end
end
```

The response will be processed by `Koalemos.Steps.Agent.ResponseParsing` which extracts:
- Assistant message content
- Tool calls
- Usage metadata

### Step 8: Implement Retry Logic

For production providers, implement progressive retry with exponential backoff:

```elixir
defp make_request_with_retry(messages, credentials, tools, config, attempt \\ 1) do
  timeouts = [45_000, 90_000, 180_000]
  timeout = Enum.at(timeouts, attempt - 1, 180_000)

  case make_request(messages, credentials, tools, config, timeout) do
    {:ok, result} ->
      {:ok, result}

    {:error, reason} when attempt < 3 ->
      Logger.warning("Request failed (attempt #{attempt}), retrying...")
      make_request_with_retry(messages, credentials, tools, config, attempt + 1)

    {:error, reason} ->
      {:error, reason}
  end
end
```

### Step 9: Add Provider to Router

Edit `lib/koalemos/steps/agent/llm_request.ex` to add your provider:

```elixir
defp resolve_provider("your_provider"), do: {:ok, Koalemos.LLMProviders.YourProvider}
```

Add credential resolution:

```elixir
defp get_credentials("your_provider", _context) do
  case Koalemos.DemoCredentialStore.get_provider_config("your_provider") do
    {:ok, config} when is_map(config) ->
      api_key = Map.get(config, "api_key", "")

      if api_key != "" do
        {:ok, %{
          provider: :your_provider,
          api_key: api_key,
          base_url: "https://api.yourprovider.com/v1"
        }}
      else
        {:error, "YourProvider API key not configured"}
      end

    {:error, reason} ->
      {:error, "Failed to get credentials: #{inspect(reason)}"}
  end
end
```

### Step 10: Write Tests

Create tests in `test/koalemos/llm_providers/your_provider_test.exs`:

```elixir
defmodule Koalemos.LLMProviders.YourProviderTest do
  use ExUnit.Case, async: true
  alias Koalemos.LLMProviders.YourProvider

  describe "call/6" do
    test "makes successful request" do
      messages = [%{role: "user", content: [%{type: "text", text: "Hi"}]}]
      credentials = %{
        provider: :your_provider,
        api_key: "test-key",
        base_url: "http://localhost:8080"
      }

      # Use a mock or test server
      assert {:ok, result} = YourProvider.call(
        messages,
        credentials,
        [],
        [],
        %{model: "test-model", max_tokens: 100, temperature: 0.5},
        "routine-123"
      )
    end

    test "handles API errors" do
      # Test error handling
    end
  end
end
```

## Example: Minimal Provider

Here's a minimal provider implementation:

```elixir
defmodule Koalemos.LLMProviders.Minimal do
  @behaviour Koalemos.LLMProvider
  alias Koalemos.LLMProvider.Utils
  require Logger

  @impl true
  def call(messages, credentials, _tools, _lens_contexts, config, routine_id) do
    Logger.info("[Minimal] Making request for routine #{routine_id}")

    # Prepare messages
    clean_messages =
      messages
      |> Enum.map(&Utils.strip_metadata/1)
      |> Utils.filter_empty_assistant_messages()

    # Make request
    case make_request(clean_messages, credentials, config) do
      {:ok, response} ->
        {:ok, [llm_response: response]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_request(messages, credentials, config) do
    url = "#{credentials.base_url}/v1/messages"

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{credentials.api_key}"}
    ]

    body = Jason.encode!(%{
      model: config.model || "default",
      messages: messages,
      max_tokens: config.max_tokens
    })

    case HTTPoison.post(url, body, headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)

      {:ok, %{status_code: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end
end
```

## Testing Your Provider

1. **Unit tests**: Test message conversion, error handling, edge cases
2. **Integration tests**: Test with mock HTTP responses
3. **Manual testing**: Use in a routine with real credentials
4. **Coverage**: Aim for 95%+ line coverage

## Existing Providers

Study these implementations as examples:

- **Anthropic** (`lib/koalemos/llm_providers/anthropic.ex`) - Phase 6d-4
  - Native Anthropic format
  - API key authentication
  - Progressive retry logic

- **OpenAI** (`lib/koalemos/llm_providers/openai.ex`) - Phase 6d-5
  - Message format conversion
  - System message handling
  - Tool schema conversion

- **Ollama** (`lib/koalemos/llm_providers/ollama.ex`) - Phase 6d-6
  - Local server (no auth)
  - OpenAI-compatible format
  - Default fallback config

## Common Utilities

Use `Koalemos.LLMProvider.Utils` for common operations:

```elixir
# Remove internal metadata
Utils.strip_metadata(message)

# Filter empty assistant messages
Utils.filter_empty_assistant_messages(messages)

# Keep only last screenshot (token optimization)
Utils.keep_only_last_screenshot(messages)
```

## Context Keys

The router step reads these keys from context:

- `:messages` - Conversation history (required)
- `:tool_descriptions` - Tool schemas from ToolSchema step
- `:lens_contexts` - Context blocks from LensRendering step
- `:llm_provider` - Provider name (default: "anthropic")
- `:llm_model` - Model name (provider-specific)
- `:max_tokens` - Token limit (default: 16384)
- `:temperature` - Sampling temperature (default: 0.1)
- `:llm_base_url` - Override base URL (optional)

## Credential Storage

Credentials are stored in `.koalemos/.credentials.json`:

```json
{
  "providers": {
    "your_provider": {
      "api_key": "sk-...",
      "model": "default-model",
      "base_url": "https://api.yourprovider.com/v1"
    }
  },
  "selected_provider": "your_provider"
}
```

Use `DemoCredentialStore.get_provider_config/1` to retrieve credentials.

## Best Practices

1. **Logging**: Use `Logger.info` for routing, `Logger.warning` for retries, `Logger.error` for failures
2. **Timeouts**: Start with 45s, increase to 90s and 180s for retries
3. **Error messages**: Include HTTP status, error codes, and context
4. **Message optimization**: Strip metadata, filter empty messages, optimize images
5. **Tests**: Cover happy path, error paths, edge cases, credential handling
6. **Documentation**: Update this guide and BACKLOG.md when adding providers

## Troubleshooting

**Provider not found**: Add to `resolve_provider/1` in LLMRequest step

**Credentials missing**: Check `.koalemos/.credentials.json` format

**Format errors**: Ensure messages match provider's expected schema

**Timeouts**: Increase timeout values or implement progressive retry

**Coverage low**: Add tests for error paths and edge cases
