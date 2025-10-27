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

  require Logger

  @default_model "gpt-4"
  @default_max_tokens 16384
  @default_temperature 0.1

  @impl true
  def call(messages, credentials, tool_descriptions, lens_contexts, config, routine_id) do
    Logger.info("[OpenAI] Making request for routine #{routine_id}")

    # Prepare messages using common utilities
    filtered_messages =
      messages
      |> Enum.map(&Utils.strip_metadata/1)
      |> Utils.filter_empty_assistant_messages()
      |> Utils.keep_only_last_screenshot()

    # Convert to OpenAI format
    openai_messages = convert_messages_to_openai(filtered_messages)

    # Build and prepend system message
    system_message = build_system_message(lens_contexts)
    all_messages = [system_message | openai_messages]

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

  # Convert Anthropic format messages to OpenAI format
  defp convert_messages_to_openai(messages) do
    messages
    |> Enum.flat_map(fn msg ->
      content = msg[:content] || msg["content"]
      role = msg[:role] || msg["role"]

      cond do
        # Handle messages with content array
        is_list(content) ->
          convert_content_array_message(role, content)

        # Handle simple text messages
        is_binary(content) ->
          [%{"role" => role, "content" => content}]

        # Empty or nil content
        true ->
          []
      end
    end)
  end

  # Convert a message with content array to OpenAI format
  defp convert_content_array_message(role, content_array) do
    # Separate tool results from other content
    {tool_results, other_content} =
      Enum.split_with(content_array, fn block ->
        type = block["type"] || block[:type]
        type == "tool_result"
      end)

    # Separate tool uses from text content
    {tool_uses, text_content} =
      Enum.split_with(other_content, fn block ->
        type = block["type"] || block[:type]
        type == "tool_use"
      end)

    result_messages = []

    # If there's text content or tool uses, create a message
    result_messages =
      if length(text_content) > 0 || length(tool_uses) > 0 do
        # Extract text
        text =
          text_content
          |> Enum.map(fn block ->
            block["text"] || block[:text] || ""
          end)
          |> Enum.join("\n")

        # If assistant with tool uses, add tool_calls
        if length(tool_uses) > 0 && role == "assistant" do
          tool_calls =
            Enum.map(tool_uses, fn tool_use ->
              %{
                "id" => tool_use["id"] || tool_use[:id],
                "type" => "function",
                "function" => %{
                  "name" => tool_use["name"] || tool_use[:name],
                  "arguments" => Jason.encode!(tool_use["input"] || tool_use[:input] || %{})
                }
              }
            end)

          [
            %{
              "role" => "assistant",
              "content" => text,
              "tool_calls" => tool_calls
            }
            | result_messages
          ]
        else
          # Regular message with text
          if text != "" do
            [%{"role" => role, "content" => text} | result_messages]
          else
            result_messages
          end
        end
      else
        result_messages
      end

    # Convert each tool_result to a separate tool message
    tool_messages =
      Enum.map(tool_results, fn tool_result ->
        tool_use_id = tool_result["tool_use_id"] || tool_result[:tool_use_id]
        result_content = tool_result["content"] || tool_result[:content]

        # Handle different content formats
        content_text =
          cond do
            is_binary(result_content) ->
              result_content

            is_list(result_content) ->
              # Extract text from content blocks
              result_content
              |> Enum.map(fn block ->
                cond do
                  is_map(block) -> block["text"] || block[:text] || ""
                  is_binary(block) -> block
                  true -> ""
                end
              end)
              |> Enum.join("\n")

            true ->
              ""
          end

        %{
          "role" => "tool",
          "tool_call_id" => tool_use_id,
          "content" => content_text
        }
      end)

    # Return all messages (text/tool_calls message + tool result messages)
    result_messages ++ tool_messages
  end

  # Build system message from lens contexts
  defp build_system_message(lens_contexts) do
    base_text = "You are Claude Code, Anthropic's official CLI for Claude."

    lens_text =
      lens_contexts
      |> Enum.map(fn context ->
        case context do
          %{"type" => "text", "text" => text} -> text
          %{type: "text", text: text} -> text
          _ -> ""
        end
      end)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")

    combined_text =
      if lens_text != "" do
        "#{base_text}\n\n#{lens_text}"
      else
        base_text
      end

    %{
      "role" => "system",
      "content" => combined_text
    }
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
          case convert_response_to_anthropic(response.body) do
            {:ok, anthropic_response} ->
              {:ok, [llm_response: anthropic_response]}

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

  # Convert OpenAI response to Anthropic format
  defp convert_response_to_anthropic(openai_response) do
    try do
      choice = openai_response["choices"] |> List.first()

      if !choice do
        {:error, "No choices in response"}
      else
        message = choice["message"]

        # Build content array
        content = []

        # Add text content if present
        content =
          if message["content"] && message["content"] != "" do
            [%{"type" => "text", "text" => message["content"]} | content]
          else
            content
          end

        # Add tool calls if present
        content =
          if message["tool_calls"] do
            tool_content =
              Enum.map(message["tool_calls"], fn tool_call ->
                tool_name = get_in(tool_call, ["function", "name"]) || ""

                # Parse arguments
                input =
                  case tool_call["function"]["arguments"] do
                    args when is_binary(args) ->
                      case Jason.decode(args) do
                        {:ok, parsed} -> parsed
                        {:error, _} -> %{}
                      end

                    args when is_map(args) ->
                      args

                    _ ->
                      %{}
                  end

                %{
                  "type" => "tool_use",
                  "id" => tool_call["id"] || "tool_#{System.unique_integer([:positive])}",
                  "name" => tool_name,
                  "input" => input
                }
              end)

            content ++ tool_content
          else
            content
          end

        # Reverse to get correct order (text first, then tools)
        content = Enum.reverse(content)

        # Determine stop reason
        stop_reason =
          case choice["finish_reason"] do
            "stop" -> "end_turn"
            "tool_calls" -> "tool_use"
            "length" -> "max_tokens"
            _ -> "end_turn"
          end

        # Build Anthropic format response
        anthropic_response = %{
          "content" => content,
          "stop_reason" => stop_reason,
          "role" => "assistant"
        }

        # Add usage if present
        anthropic_response =
          if openai_response["usage"] do
            Map.put(anthropic_response, "usage", %{
              "input_tokens" => openai_response["usage"]["prompt_tokens"] || 0,
              "output_tokens" => openai_response["usage"]["completion_tokens"] || 0
            })
          else
            anthropic_response
          end

        {:ok, anthropic_response}
      end
    rescue
      error ->
        {:error, "Failed to parse response: #{inspect(error)}"}
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
