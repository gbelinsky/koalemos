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
  1. First attempt: 2 minutes (120 seconds)
  2. Second attempt: 4 minutes (240 seconds)
  3. Third attempt: 8 minutes (480 seconds)

  Retryable HTTP status codes: 429, 500, 502, 503, 504, 529
  """

  @behaviour Koalemos.LLMProvider
  alias Koalemos.LLMProvider.Utils

  require Logger
  require Koalemos.Log
  alias Koalemos.Log

  @default_model "claude-sonnet-4-5-20250929"
  @default_max_tokens 16384
  @default_temperature 0.1
  # Progressive timeouts for retries: 2min, 4min, 8min
  # Longer timeouts support large responses (e.g., retrospective documents with 6k+ tokens)
  @timeouts [120_000, 240_000, 480_000]

  @impl true
  def call(messages, credentials, tool_descriptions, lens_contexts, config, routine_id) do
    # Validate credentials early to provide clear error message
    case validate_credentials(credentials) do
      :ok ->
        do_call(messages, credentials, tool_descriptions, lens_contexts, config, routine_id)

      {:error, reason} ->
        Logger.error("[Anthropic] #{reason}")
        {:error, reason}
    end
  end

  defp do_call(messages, credentials, tool_descriptions, lens_contexts, config, routine_id) do
    Log.debug(:llm, "[Anthropic] Making request for routine #{routine_id}")

    Log.debug(:llm, fn ->
      "[LLM] Request details - messages: #{length(messages)}, tools: #{length(tool_descriptions)}"
    end)

    # Extract text and image contexts
    text_contexts = Map.get(lens_contexts, :text, [])
    image_contexts = Map.get(lens_contexts, :images, [])

    # Debug: Log image context status
    if length(image_contexts) > 0 do
      Log.debug(:llm, "[Anthropic] Including #{length(image_contexts)} image(s)")
    end

    # Build system content with text contexts and step prompt
    step_prompt = Map.get(lens_contexts, :step_prompt)
    system_content = build_system_content(text_contexts, step_prompt)

    # Log complete system prompt when :prompts domain enabled
    Log.info(:prompts, fn ->
      prompt_text = system_content
        |> Enum.map(fn %{text: text} -> text end)
        |> Enum.join("\n\n---\n\n")
      "[Prompt] System content (#{length(system_content)} blocks):\n#{prompt_text}"
    end)

    # Prepare messages using common utilities
    filtered_messages =
      messages
      |> Enum.map(&Utils.strip_metadata/1)
      |> Utils.filter_empty_assistant_messages()

    # Append image contexts as user messages at the END (not saved to history)
    # Include descriptive text to emphasize these are current/live views
    # Placed at end so agent sees them most recently and pays more attention
    image_messages =
      Enum.map(image_contexts, fn img ->
        %{
          role: "user",
          content: [
            %{type: "text", text: "Live screen view - current visual state of the wireframe:"},
            img
          ]
        }
      end)

    all_messages = filtered_messages ++ image_messages

    # Log messages when :prompts domain enabled
    Log.info(:prompts, fn ->
      msg_summary = Enum.map(all_messages, fn msg ->
        role = msg[:role] || msg["role"]
        content = msg[:content] || msg["content"]
        content_preview = case content do
          text when is_binary(text) ->
            if String.length(text) > 200, do: String.slice(text, 0, 200) <> "...", else: text
          blocks when is_list(blocks) ->
            "[#{length(blocks)} content blocks]"
          _ ->
            inspect(content, limit: 100)
        end
        "  #{role}: #{content_preview}"
      end)
      "[Prompt] Messages (#{length(all_messages)}):\n#{Enum.join(msg_summary, "\n")}"
    end)

    # Get model parameters from config with defaults
    model = config[:model] || @default_model
    max_tokens = config[:max_tokens] || @default_max_tokens
    temperature = config[:temperature] || @default_temperature

    Log.debug(:llm, "[Anthropic] Using model: #{model}")

    # Build request body
    json_body = %{
      model: model,
      max_tokens: max_tokens,
      temperature: temperature,
      system: system_content,
      messages: all_messages
    }

    Log.debug(:llm, fn ->
      system_size = system_content |> Enum.map(&byte_size(Map.get(&1, :text, ""))) |> Enum.sum()
      "[LLM] System content: #{length(system_content)} blocks, ~#{system_size} bytes"
    end)

    # Add tools if any are available
    json_body =
      if length(tool_descriptions) > 0 do
        Log.debug(:llm, "[Anthropic] Including #{length(tool_descriptions)} tools")

        # Log tool names when :prompts domain enabled
        Log.info(:prompts, fn ->
          tool_names = Enum.map(tool_descriptions, fn tool ->
            "  - #{tool[:name] || tool["name"]}"
          end)
          "[Prompt] Tools (#{length(tool_descriptions)}):\n#{Enum.join(tool_names, "\n")}"
        end)

        Map.put(json_body, :tools, tool_descriptions)
      else
        json_body
      end

    # Make request with progressive retry
    make_request_with_retry(credentials, json_body, @timeouts, 1, routine_id)
  end

  # Make HTTP request with progressive retry and exponential backoff
  defp make_request_with_retry(
         credentials,
         json_body,
         [timeout | remaining_timeouts],
         attempt,
         routine_id
       ) do
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
          Log.debug(:llm, "[Anthropic] Request succeeded (attempt #{attempt})")

          Log.debug(:llm, fn ->
            usage = Map.get(response.body, "usage", %{})
            "[LLM] Response - input: #{Map.get(usage, "input_tokens", "?")} tokens, output: #{Map.get(usage, "output_tokens", "?")} tokens"
          end)

          {:ok, [{:add_or_update, %{llm_response: response.body}}]}

        {:ok, %{status: status, headers: headers} = response}
        when status in [429, 500, 502, 503, 504, 529] and remaining_timeouts != [] ->
          # Retryable server errors - use header-based delay for 429, exponential backoff otherwise
          backoff_ms = extract_retry_delay(headers, status, attempt)

          # Log rate limit details for 429
          if status == 429 do
            log_rate_limit_info(headers, response.body)
          end

          Logger.warning(
            "[Anthropic] Retryable error #{status} (attempt #{attempt}), retrying after #{backoff_ms}ms"
          )

          :timer.sleep(backoff_ms)

          make_request_with_retry(
            credentials,
            json_body,
            remaining_timeouts,
            attempt + 1,
            routine_id
          )

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

          make_request_with_retry(
            credentials,
            json_body,
            remaining_timeouts,
            attempt + 1,
            routine_id
          )

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

  # Validate that required credentials are present
  defp validate_credentials(nil), do: {:error, "Missing credentials - configure API key in settings"}

  defp validate_credentials(credentials) when is_map(credentials) do
    case Map.get(credentials, :api_key) do
      nil -> {:error, "Missing api_key in credentials - configure API key in settings"}
      "" -> {:error, "Empty api_key in credentials - configure API key in settings"}
      _key -> :ok
    end
  end

  defp validate_credentials(_), do: {:error, "Invalid credentials format"}

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

  # Build system content by combining base prompt with lens contexts and step prompt
  defp build_system_content(lens_contexts, step_prompt) do
    base_content = %{
      type: "text",
      text: "You are Claude Code, Anthropic's official CLI for Claude."
    }

    # Convert lens contexts to proper format (handle both strings and already-formatted maps)
    formatted_lens_contexts =
      Enum.map(lens_contexts, fn context ->
        case context do
          # Already formatted correctly
          %{"type" => "text", "text" => text} when is_binary(text) ->
            %{type: "text", text: text}

          %{type: "text", text: text} when is_binary(text) ->
            %{type: "text", text: text}

          # Plain string
          text when is_binary(text) ->
            %{type: "text", text: text}

          # Fallback for unexpected formats
          _ ->
            %{type: "text", text: inspect(context)}
        end
      end)

    # Step prompt at the end (instruction for this turn) - most recent = most attention
    step_prompt_content =
      case step_prompt do
        nil ->
          []
        prompt when is_binary(prompt) ->
          trimmed = String.trim(prompt)
          if trimmed != "", do: [%{type: "text", text: prompt}], else: []
        _ ->
          []
      end

    # Combine all blocks and filter out empty ones
    all_blocks = [base_content] ++ formatted_lens_contexts ++ step_prompt_content

    Enum.filter(all_blocks, fn block ->
      case block do
        %{type: "text", text: text} when is_binary(text) ->
          String.trim(text) != ""
        _ ->
          true
      end
    end)
  end

  # Extract retry delay from rate limit headers, fall back to exponential backoff
  defp extract_retry_delay(headers, status, attempt) do
    cond do
      # For 429, try to use rate limit headers
      status == 429 ->
        case get_header_retry_delay(headers) do
          {:ok, delay_ms} -> delay_ms
          :not_found -> exponential_backoff(attempt)
        end

      # For other retryable errors, use exponential backoff
      true ->
        exponential_backoff(attempt)
    end
  end

  # Try to extract delay from Anthropic rate limit headers
  defp get_header_retry_delay(headers) do
    # Req returns headers as a map with lowercase keys
    headers_map = headers_to_map(headers)

    # Check retry-after first (standard HTTP header, value in seconds)
    case get_header_value(headers_map, "retry-after") do
      nil -> :not_found
      seconds_str ->
        case Integer.parse(seconds_str) do
          {seconds, _} ->
            delay_ms = seconds * 1000
            Logger.info("[Anthropic] Using retry-after header: #{seconds}s")
            {:ok, delay_ms}
          :error ->
            # Could be an HTTP-date, try parsing as ISO timestamp
            try_parse_reset_timestamp(seconds_str)
        end
    end
    |> case do
      {:ok, delay} -> {:ok, delay}
      :not_found ->
        # Fall back to anthropic-ratelimit-tokens-reset (ISO timestamp)
        case get_header_value(headers_map, "anthropic-ratelimit-tokens-reset") do
          nil -> :not_found
          timestamp_str -> try_parse_reset_timestamp(timestamp_str)
        end
    end
  end

  # Get header value, handling both single values and lists
  defp get_header_value(headers_map, key) do
    case Map.get(headers_map, key) do
      nil -> nil
      [value | _] -> to_string(value)  # Take first value if list
      value -> to_string(value)
    end
  end

  # Parse ISO timestamp and calculate delay until that time
  defp try_parse_reset_timestamp(timestamp_str) do
    case DateTime.from_iso8601(timestamp_str) do
      {:ok, reset_time, _offset} ->
        now = DateTime.utc_now()
        diff_seconds = DateTime.diff(reset_time, now, :second)
        # Add 1 second buffer, minimum 1 second wait
        delay_ms = max(diff_seconds + 1, 1) * 1000
        Logger.info("[Anthropic] Rate limit resets at #{timestamp_str}, waiting #{delay_ms}ms")
        {:ok, delay_ms}

      {:error, _} ->
        :not_found
    end
  end

  # Convert headers to a simple map for easier lookup
  defp headers_to_map(headers) when is_list(headers) do
    Enum.into(headers, %{}, fn {key, value} ->
      {String.downcase(to_string(key)), to_string(value)}
    end)
  end
  defp headers_to_map(headers) when is_map(headers), do: headers
  defp headers_to_map(_), do: %{}

  # Exponential backoff: 1s, 2s, 4s, 8s, ... capped at 30s
  defp exponential_backoff(attempt) do
    min(1000 * :math.pow(2, attempt - 1), 30_000) |> round()
  end

  # Log rate limit information for debugging
  defp log_rate_limit_info(headers, body) do
    headers_map = headers_to_map(headers)

    # Extract useful rate limit headers
    remaining = get_header_value(headers_map, "anthropic-ratelimit-tokens-remaining")
    limit = get_header_value(headers_map, "anthropic-ratelimit-tokens-limit")
    reset = get_header_value(headers_map, "anthropic-ratelimit-tokens-reset")

    # Extract error message from body
    error_msg = case body do
      %{"error" => %{"message" => msg}} -> msg
      _ -> "Rate limited"
    end

    Logger.warning("""
    [Anthropic] Rate limit hit (429):
      Message: #{error_msg}
      Tokens remaining: #{remaining || "unknown"}
      Tokens limit: #{limit || "unknown"}
      Reset at: #{reset || "unknown"}
    """)
  end
end
