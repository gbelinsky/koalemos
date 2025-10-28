defmodule Koalemos.LLMProviders.Ollama do
  @moduledoc """
  Ollama API provider.

  Implements the LLMProvider behavior for Ollama's OpenAI-compatible API.

  ## Features

  - Message format conversion (Anthropic → OpenAI format, via OpenAIFormatConverter)
  - Tool schema conversion (Anthropic → OpenAI format)
  - Response conversion (OpenAI → Anthropic format)
  - System message as first message in array
  - No authentication required (local server)

  ## Configuration

  Credentials include:
  - `base_url` - API endpoint (default: http://localhost:11434)
  - `model` - Model name (default: llama2)

  Config parameters:
  - `model` - Model name (overrides credential default)
  - `max_tokens` - Maximum tokens (default: 16384)
  - `temperature` - Sampling temperature (default: 0.1)

  ## Available Models

  Common Ollama models include:
  - llama2, llama3
  - mistral, mixtral
  - qwen, qwen2, qwen3
  - deepseek-r1
  - codellama
  - phi

  Use `ollama list` to see installed models.
  """

  @behaviour Koalemos.LLMProvider
  alias Koalemos.LLMProvider.Utils
  alias Koalemos.ToolSchemaConverter
  alias Koalemos.OpenAIFormatConverter

  require Logger

  @default_base_url "http://localhost:11434"
  @default_model "llama2"
  @default_max_tokens 16384
  @default_temperature 0.1

  @impl true
  def call(messages, credentials, tool_descriptions, lens_contexts, config, routine_id) do
    Logger.info("[Ollama] Making request for routine #{routine_id}")

    # Extract text and image contexts
    text_contexts = Map.get(lens_contexts, :text, [])
    image_contexts = Map.get(lens_contexts, :images, [])

    # Prepare messages using common utilities
    filtered_messages =
      messages
      |> Enum.map(&Utils.strip_metadata/1)
      |> Utils.filter_empty_assistant_messages()

    # Convert to OpenAI format (Ollama uses OpenAI-compatible API)
    openai_messages = OpenAIFormatConverter.convert_messages_to_openai(filtered_messages)

    # Build system message from text contexts
    system_message = OpenAIFormatConverter.build_system_message(text_contexts)

    # Convert image contexts to user messages
    image_messages = Enum.map(image_contexts, fn img ->
      %{"role" => "user", "content" => [img]}
    end)

    # Combine: system, images, actual messages
    all_messages = [system_message] ++ image_messages ++ openai_messages

    # Get model parameters from config with defaults
    model = config[:model] || credentials.model || @default_model
    max_tokens = config[:max_tokens] || @default_max_tokens
    temperature = config[:temperature] || @default_temperature

    Logger.info("[Ollama] Using model: #{model}")

    # Build request body (note: Ollama uses max_tokens, not max_completion_tokens)
    json_body = %{
      model: model,
      max_tokens: max_tokens,
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

  # Make HTTP request to Ollama API
  defp make_request(credentials, json_body, _routine_id) do
    base_url = credentials.base_url || @default_base_url
    url = "#{base_url}/v1/chat/completions"

    # Ollama doesn't require authentication headers
    headers = [{"content-type", "application/json"}]

    try do
      case Req.post(url,
             headers: headers,
             json: json_body,
             receive_timeout: 120_000
           ) do
        {:ok, %{status: 200} = response} ->
          Logger.info("[Ollama] Request succeeded")

          # Convert OpenAI response to Anthropic format
          case OpenAIFormatConverter.convert_response_to_anthropic(response.body) do
            {:ok, anthropic_response} ->
              {:ok, [{:add, %{llm_response: anthropic_response}}]}

            {:error, reason} ->
              {:error, "Failed to convert Ollama response: #{reason}"}
          end

        {:ok, %{status: status} = response} ->
          # API error
          error_msg =
            case response.body do
              %{"error" => %{"message" => msg}} -> msg
              %{"error" => error} when is_binary(error) -> error
              _ -> "Unknown API error"
            end

          Logger.error("[Ollama] API error #{status}: #{error_msg}")
          {:error, "API error #{status}: #{error_msg}"}

        {:error, %{reason: :econnrefused}} ->
          Logger.error("[Ollama] Connection refused - is Ollama running at #{base_url}?")
          {:error, "Connection refused - is Ollama running at #{base_url}?"}

        {:error, reason} ->
          Logger.error("[Ollama] Request failed: #{inspect(reason)}")
          {:error, "Request failed: #{inspect(reason)}"}
      end
    rescue
      error in ArgumentError ->
        Logger.error("[Ollama] Invalid request: #{error.message}")
        {:error, "Invalid request: #{error.message}"}
    end
  end
end
