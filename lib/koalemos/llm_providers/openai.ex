defmodule Koalemos.LLMProviders.OpenAI do
  @moduledoc """
  OpenAI API provider.

  Implements the LLMProvider behavior for OpenAI's Chat Completions API.

  ## Features

  - Message format conversion (Anthropic → OpenAI)
  - Tool schema conversion (Anthropic → OpenAI)
  - Response conversion (OpenAI → Anthropic)
  - System message as first message in array
  - Bearer token authentication

  ## Message Format Differences

  **Anthropic:**
  - Content is array of blocks: `[{type: "text", text: "..."}, {type: "tool_use", ...}]`
  - Tool results in user messages as `tool_result` blocks

  **OpenAI:**
  - Content is string
  - Tool calls in separate `tool_calls` array
  - Tool results as separate messages with `role: "tool"`

  ## Configuration

  Credentials include:
  - `api_key` - OpenAI API key
  - `base_url` - API endpoint (default: https://api.openai.com/v1)

  Config parameters:
  - `model` - Model name (default: gpt-4)
  - `max_tokens` - Maximum tokens (default: 16384)
  - `temperature` - Sampling temperature (default: 0.1)
  """

  @behaviour Koalemos.LLMProvider
  alias Koalemos.LLMProvider.Utils
  alias Koalemos.ToolSchemaConverter
  alias Koalemos.OpenAIFormatConverter

  require Logger

  @default_model "gpt-4"
  @default_max_tokens 16384
  @default_temperature 0.1

  @impl true
  def call(messages, credentials, tool_descriptions, lens_contexts, config, routine_id) do
    Logger.info("[OpenAI] Making request for routine #{routine_id}")

    # Extract text and image contexts
    text_contexts = Map.get(lens_contexts, :text, [])
    image_contexts = Map.get(lens_contexts, :images, [])

    # Prepare messages using common utilities
    filtered_messages =
      messages
      |> Enum.map(&Utils.strip_metadata/1)
      |> Utils.filter_empty_assistant_messages()

    # Convert to OpenAI format
    openai_messages = OpenAIFormatConverter.convert_messages_to_openai(filtered_messages)

    # Build system message from text contexts
    system_message = OpenAIFormatConverter.build_system_message(text_contexts)

    # Convert image contexts to user messages
    image_messages =
      Enum.map(image_contexts, fn img ->
        %{"role" => "user", "content" => [img]}
      end)

    # Combine: system, images, actual messages
    all_messages = [system_message] ++ image_messages ++ openai_messages

    # Get model parameters from config with defaults
    model = config[:model] || @default_model
    max_tokens = config[:max_tokens] || @default_max_tokens
    temperature = config[:temperature] || @default_temperature

    Logger.info("[OpenAI] Using model: #{model}")

    # Build request body
    json_body = %{
      model: model,
      max_completion_tokens: max_tokens,
      temperature: temperature,
      messages: all_messages
    }

    # Convert and add tools if any are available
    json_body =
      if length(tool_descriptions) > 0 do
        openai_tools = ToolSchemaConverter.anthropic_to_openai(tool_descriptions)
        Map.put(json_body, :tools, openai_tools)
      else
        json_body
      end

    # Make request
    make_request(credentials, json_body, routine_id)
  end

  # Make HTTP request to OpenAI API
  defp make_request(credentials, json_body, _routine_id) do
    headers = build_headers(credentials)
    url = "#{credentials.base_url}/chat/completions"

    try do
      case Req.post(url,
             headers: headers,
             json: json_body,
             receive_timeout: 120_000
           ) do
        {:ok, %{status: 200} = response} ->
          Logger.info("[OpenAI] Request succeeded")

          # Convert OpenAI response to Anthropic format
          case OpenAIFormatConverter.convert_response_to_anthropic(response.body) do
            {:ok, anthropic_response} ->
              {:ok, [{:add_or_update, %{llm_response: anthropic_response}}]}

            {:error, reason} ->
              {:error, "Failed to convert OpenAI response: #{reason}"}
          end

        {:ok, %{status: status} = response} ->
          # API error
          error_msg =
            case response.body do
              %{"error" => %{"message" => msg}} -> msg
              %{"error" => error} when is_binary(error) -> error
              _ -> "Unknown API error"
            end

          Logger.error("[OpenAI] API error #{status}: #{error_msg}")
          {:error, "API error #{status}: #{error_msg}"}

        {:error, %{reason: :econnrefused}} ->
          Logger.error("[OpenAI] Connection refused - check base_url and network")
          {:error, "Connection refused - check base_url and network connectivity"}

        {:error, reason} ->
          Logger.error("[OpenAI] Request failed: #{inspect(reason)}")
          {:error, "Request failed: #{inspect(reason)}"}
      end
    rescue
      error in ArgumentError ->
        Logger.error("[OpenAI] Invalid request: #{error.message}")
        {:error, "Invalid request: #{error.message}"}
    end
  end

  # Build HTTP headers for OpenAI API
  defp build_headers(credentials) do
    [
      {"content-type", "application/json"},
      {"authorization", "Bearer #{credentials.api_key}"}
    ]
  end
end
