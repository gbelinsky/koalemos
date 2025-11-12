defmodule Koalemos.Steps.Agent.ResponseParsing do
  @moduledoc """
  ResponseParsing step transforms raw LLM API responses into structured data.

  Pure data transformation step that:
  - Extracts assistant message content from LLM response
  - Appends assistant message to conversation history
  - Extracts tool calls into structured format (if any)

  ## Context Input
  - llm_response: raw API response from LLMRequest step
  - messages: existing conversation array

  ## Context Output
  - messages: updated with assistant's response appended
  - tool_calls: list of %{id, name, input} (only if tools were called)

  ## Example

  ```elixir
  response_parsing: %{
    type: Koalemos.Steps.Agent.ResponseParsing,
    transitions: [
      {:execute_tools, fn state -> state.context[:tool_calls] != nil end},
      {:continue, :always}
    ]
  }
  ```
  """

  require Logger

  @doc """
  Parse LLM response and extract assistant message and tool calls.
  """
  def execute(_config, state) do
    llm_response = Map.get(state.context, :llm_response)

    case llm_response do
      %{"content" => content} when is_list(content) ->
        # Extract usage data (input_tokens, output_tokens) from API response
        usage = Map.get(llm_response, "usage", %{})

        # Build assistant message for conversation history with metadata
        assistant_message =
          Koalemos.Utils.MessageBuilder.build_assistant_message(
            content,
            source: :agent,
            routine_id: state.routine_id,
            usage: usage
          )

        Logger.debug(
          "ResponseParsing: Assistant message built (id: #{get_in(assistant_message, [:metadata, :id])})"
        )

        # Log detailed content breakdown
        content_summary = summarize_content(content)
        Logger.info("[ResponseParsing] Content summary: #{content_summary}")

        # Log token usage for debugging
        if map_size(usage) > 0 do
          Logger.info(
            "Tokens - Input: #{Map.get(usage, "input_tokens", 0)}, Output: #{Map.get(usage, "output_tokens", 0)}"
          )
        end

        # Extract tool calls if any
        tool_calls = extract_tool_calls(content)

        if length(tool_calls) > 0 do
          tool_names = Enum.map(tool_calls, & &1.name) |> Enum.join(", ")
          Logger.info("[ResponseParsing] Tool calls: #{length(tool_calls)} tools - #{tool_names}")
        else
          Logger.info("[ResponseParsing] No tool calls in response")
        end

        # Build context diff using append_to for messages
        diff = [append_to: %{messages: [assistant_message]}]

        # Add tool_calls if present
        diff =
          if length(tool_calls) > 0 do
            diff ++ [add_or_update: %{tool_calls: tool_calls}]
          else
            diff
          end

        {:ok, diff}

      %{"content" => content} ->
        {:error, "Expected content to be a list, got: #{inspect(content)}"}

      _ ->
        {:error, "No content found in LLM response: #{inspect(llm_response)}"}
    end
  end

  # Extract tool calls from content blocks
  defp extract_tool_calls(content) do
    content
    |> Enum.filter(fn block ->
      Map.get(block, "type") == "tool_use"
    end)
    |> Enum.map(fn tool_block ->
      %{
        id: Map.get(tool_block, "id"),
        name: Map.get(tool_block, "name"),
        input: Map.get(tool_block, "input", %{})
      }
    end)
  end

  # Summarize content blocks for logging
  defp summarize_content(content) do
    total = length(content)

    # Count by type
    type_counts =
      Enum.reduce(content, %{}, fn block, acc ->
        type = Map.get(block, "type", "unknown")
        Map.update(acc, type, 1, &(&1 + 1))
      end)

    # Format: "5 blocks (3 text, 2 tool_use)"
    type_parts =
      Enum.map(type_counts, fn {type, count} ->
        "#{count} #{type}"
      end)
      |> Enum.join(", ")

    "#{total} blocks (#{type_parts})"
  end
end
