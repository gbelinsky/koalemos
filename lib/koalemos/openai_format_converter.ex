defmodule Koalemos.OpenAIFormatConverter do
  @moduledoc """
  Converts messages and responses between Anthropic and OpenAI formats.

  This module provides conversion functions used by both OpenAI and Ollama providers,
  since they use the same message format.

  ## Anthropic Format

  **Messages:**
  - Content is array of blocks: `[{type: "text", text: "..."}, {type: "tool_use", ...}]`
  - Tool results in user messages as `tool_result` blocks
  - System content as separate field with array of blocks

  **Response:**
  ```elixir
  %{
    "content" => [
      %{"type" => "text", "text" => "..."},
      %{"type" => "tool_use", "id" => "...", "name" => "...", "input" => %{}}
    ],
    "stop_reason" => "end_turn" | "tool_use" | "max_tokens",
    "usage" => %{"input_tokens" => 100, "output_tokens" => 50}
  }
  ```

  ## OpenAI/Ollama Format

  **Messages:**
  - Content is string
  - Tool calls in separate `tool_calls` array
  - Tool results as separate messages with `role: "tool"`
  - System message as first message in array

  **Response:**
  ```elixir
  %{
    "choices" => [
      %{
        "message" => %{
          "role" => "assistant",
          "content" => "...",
          "tool_calls" => [...]
        },
        "finish_reason" => "stop" | "tool_calls" | "length"
      }
    ],
    "usage" => %{"prompt_tokens" => 100, "completion_tokens" => 50}
  }
  ```
  """

  @doc """
  Convert Anthropic format messages to OpenAI/Ollama format.

  Handles:
  - Content arrays → Concatenated strings
  - Tool use blocks → tool_calls array
  - Tool result blocks → Separate "tool" role messages

  ## Examples

      iex> messages = [%{role: "user", content: [%{type: "text", text: "Hello"}]}]
      iex> [result] = Koalemos.OpenAIFormatConverter.convert_messages_to_openai(messages)
      iex> result["role"]
      "user"
      iex> result["content"]
      "Hello"
  """
  def convert_messages_to_openai(messages) do
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

  @doc """
  Convert a message with content array to OpenAI/Ollama format.

  Handles complex scenarios:
  - Text content
  - Tool use blocks (assistant messages)
  - Tool result blocks (user messages)
  - Mixed content
  """
  def convert_content_array_message(role, content_array) do
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

  @doc """
  Build system message from lens contexts for OpenAI/Ollama format.

  Returns a message with role="system" and combined text content.

  ## Examples

      iex> lens_contexts = [%{type: "text", text: "Context 1"}]
      iex> result = Koalemos.OpenAIFormatConverter.build_system_message(lens_contexts)
      iex> result["role"]
      "system"
  """
  def build_system_message(lens_contexts) do
    base_text = ""

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

  @doc """
  Convert OpenAI/Ollama response to Anthropic format.

  Handles:
  - Text content → text block in content array
  - tool_calls → tool_use blocks in content array
  - Stop reasons mapping
  - Usage tokens mapping
  """
  def convert_response_to_anthropic(openai_response) do
    try do
      choice = openai_response["choices"] |> List.first()

      if !choice do
        {:error, "No choices in response"}
      else
        message = choice["message"]

        # Build content array
        content = []

        # Add text content if present (try content first, then reasoning for reasoning models)
        text_content =
          cond do
            message["content"] && message["content"] != "" ->
              message["content"]

            message["reasoning"] && message["reasoning"] != "" ->
              # Reasoning models (like qwen3) return content in "reasoning" field
              message["reasoning"]

            true ->
              nil
          end

        content =
          if text_content do
            [%{"type" => "text", "text" => text_content} | content]
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

            tool_content ++ content
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
end
