defmodule Koalemos.LLMProviders.Anthropic do
  @moduledoc """
  Anthropic Claude API provider.

  Implements the LLMProvider behavior for Anthropic's Claude API.
  Supports both API key and OAuth authentication.

  ## Features

  - Native Anthropic message format (no conversion needed)
  - API key and OAuth authentication
  - Progressive retry logic with exponential backoff
  - System content as array of blocks
  - Tool/function calling support
  - Image/screenshot support

  ## Configuration

  Credentials are resolved by `Koalemos.Steps.Agent.LLMRequest` and include:
  - `api_key` - API key or OAuth access token
  - `auth_type` - `:api_key` or `:oauth`
  - `base_url` - API endpoint (default: https://api.anthropic.com/v1)

  Config parameters:
  - `model` - Model name (default: claude-sonnet-4-5-20250929)
  - `max_tokens` - Maximum tokens (default: 16384)
  - `temperature` - Sampling temperature (default: 0.1)

  ## Progressive Retry

  Requests are retried with increasing timeouts:
  1. First attempt: 45 seconds
  2. Second attempt: 90 seconds
  3. Third attempt: 180 seconds

  Retryable HTTP status codes: 429, 500, 502, 503, 504, 529
  """

  @behaviour Koalemos.LLMProvider
  alias Koalemos.LLMProvider.Utils

  require Logger

  @default_model "claude-sonnet-4-5-20250929"
  @default_max_tokens 16384
  @default_temperature 0.1
  @timeouts [45_000, 90_000, 180_000]

  @impl true
  def call(messages, credentials, tool_descriptions, lens_contexts, config, routine_id) do
    Logger.info("[Anthropic] Making request for routine #{routine_id}")

    # Build system content with lens contexts
    system_content = build_system_content(lens_contexts)

    # Prepare messages using common utilities
    filtered_messages =
      messages
      |> Enum.map(&Utils.strip_metadata/1)
      |> Utils.filter_empty_assistant_messages()
      |> Utils.keep_only_last_screenshot()

    # Get model parameters from config with defaults
    model = config[:model] || @default_model
    max_tokens = config[:max_tokens] || @default_max_tokens
    temperature = config[:temperature] || @default_temperature

    Logger.info("[Anthropic] Using model: #{model}")

    # Build request body
    json_body = %{
      model: model,
      max_tokens: max_tokens,
      temperature: temperature,
      system: system_content,
      messages: filtered_messages
    }

    # Add tools if any are available
    json_body =
      if length(tool_descriptions) > 0 do
        Map.put(json_body, :tools, tool_descriptions)
      else
        json_body
      end

    # Make request with progressive retry
    make_request_with_retry(credentials, json_body, @timeouts, 1, routine_id)
  end

  # Make HTTP request with progressive retry and exponential backoff
  defp make_request_with_retry(credentials, json_body, [timeout | remaining_timeouts], attempt, routine_id) do
    # Build headers based on auth type
    headers = build_headers(credentials)

    url = "#{credentials.base_url}/messages"

    try do
      case Req.post(url,
             headers: headers,
             json: json_body,
             receive_timeout: timeout,
             retry: false
           ) do
        {:ok, %{status: 200} = response} ->
          Logger.info("[Anthropic] Request succeeded (attempt #{attempt})")
          {:ok, [llm_response: response.body]}

        {:ok, %{status: status} = _response}
        when status in [429, 500, 502, 503, 504, 529] and remaining_timeouts != [] ->
          # Retryable server errors - exponential backoff
          backoff_ms = min(1000 * :math.pow(2, attempt - 1), 30_000) |> round()
          Logger.warning("[Anthropic] Retryable error #{status} (attempt #{attempt}), retrying after #{backoff_ms}ms")
          :timer.sleep(backoff_ms)
          make_request_with_retry(credentials, json_body, remaining_timeouts, attempt + 1, routine_id)

        {:ok, %{status: status} = response} ->
          # Non-retryable error
          error_msg =
            case response.body do
              %{"error" => %{"message" => msg}} -> msg
              %{"error" => error} when is_binary(error) -> error
              _ -> "Unknown API error"
            end

          Logger.error("[Anthropic] API error #{status}: #{error_msg}")
          {:error, "API error #{status}: #{error_msg}"}

        {:error, %{reason: :timeout}} when remaining_timeouts != [] ->
          # Retry with longer timeout
          Logger.warning("[Anthropic] Timeout (attempt #{attempt}), retrying with longer timeout")
          make_request_with_retry(credentials, json_body, remaining_timeouts, attempt + 1, routine_id)

        {:error, %{reason: :timeout}} ->
          # Final timeout after all retries
          Logger.error("[Anthropic] Request timeout after #{attempt} attempts")
          {:error, "Request timeout after #{attempt} attempts"}

        {:error, %{reason: :econnrefused}} ->
          Logger.error("[Anthropic] Connection refused - check base_url and network")
          {:error, "Connection refused - check base_url and network connectivity"}

        {:error, reason} ->
          Logger.error("[Anthropic] Request failed: #{inspect(reason)}")
          {:error, "Request failed: #{inspect(reason)}"}
      end
    rescue
      error in ArgumentError ->
        Logger.error("[Anthropic] Invalid request: #{error.message}")
        {:error, "Invalid request: #{error.message}"}
    end
  end

  defp make_request_with_retry(_credentials, _json_body, [], attempt, _routine_id) do
    Logger.error("[Anthropic] Maximum retry attempts (#{attempt - 1}) exceeded")
    {:error, "Maximum retry attempts (#{attempt - 1}) exceeded"}
  end

  # Build HTTP headers based on authentication type
  defp build_headers(credentials) do
    base_headers = [
      {"content-type", "application/json"},
      {"anthropic-version", "2023-06-01"}
    ]

    # Add auth header based on auth type
    auth_header =
      case Map.get(credentials, :auth_type, :api_key) do
        :api_key ->
          {"x-api-key", credentials.api_key}

        :oauth ->
          {"authorization", "Bearer #{credentials.api_key}"}
      end

    # Add beta header based on auth type
    beta_header =
      case Map.get(credentials, :auth_type, :api_key) do
        :oauth ->
          {"anthropic-beta", "claude-code-20250219,oauth-2025-04-20"}

        :api_key ->
          {"anthropic-beta", "claude-code-20250219"}
      end

    base_headers ++ [auth_header, beta_header]
  end

  # Build system content by combining base prompt with lens contexts
  defp build_system_content(lens_contexts) do
    base_content = %{
      type: "text",
      text: "You are Claude Code, Anthropic's official CLI for Claude."
    }

    [base_content | lens_contexts]
  end
end
