defmodule Koalemos.Steps.Agent.ToolLookup do
  @moduledoc """
  ToolLookup resolves tool calls to executable format using the tool map.

  Takes tool calls from ResponseParsingNode and uses the tool_map from ToolSchemaNode
  to resolve tool names to executable {module, function} pairs.

  When a tool is not found, instead of failing the workflow, we return an error
  message as a tool_result back to the agent, allowing it to recover and try again.

  ## Context Input
  - tool_calls: List of %{id, name, input} from ResponseParsingNode
  - tool_map: Map of tool_name → {module, function} from ToolSchemaNode
  - messages: Conversation history

  ## Context Output
  - to_execute: List of %{id, module, function, input} ready for ToolExecutionNode
  - messages: Updated with error tool results for any invalid tools (appended)
  - Removes tool_calls from context

  ## Example

  ```elixir
  lookup_tools: %{
    type: Koalemos.Steps.Agent.ToolLookup,
    transitions: [{:execute_tools, :always}]
  }
  ```
  """

  alias Koalemos.Utils.MessageBuilder
  require Logger

  @doc """
  Resolves tool calls to executable format.
  """
  def execute(_config, state) do
    tool_calls = Map.get(state.context, :tool_calls, [])
    tool_map = Map.get(state.context, :tool_map, %{})

    case {tool_calls, tool_map} do
      {[], _} ->
        # No tool calls to process
        {:ok, [add_or_update: %{to_execute: []}]}

      {_, tool_map} when map_size(tool_map) == 0 ->
        # This is a configuration error - no tools available at all
        {:error, "No tool map available for tool lookup"}

      {calls, map} ->
        # Resolve all tool calls - separating valid from invalid
        {valid_tools, error_results} = resolve_tool_calls(calls, map, state.routine_id)

        # Build diff - use append_to for error messages
        base_diff = [
          remove: [:tool_calls],
          add_or_update: %{to_execute: valid_tools}
        ]

        # Add error messages using append_to if there are any
        final_diff = if error_results != [] do
          Enum.each(error_results, fn msg ->
            msg_id = get_in(msg, [:metadata, :id])
            source = get_in(msg, [:metadata, :source])
            Logger.info("[ToolLookup] Appending error message id=#{msg_id}, source=#{source}")
          end)
          base_diff ++ [append_to: %{messages: error_results}]
        else
          base_diff
        end

        {:ok, final_diff}
    end
  end

  # Resolve each tool call to executable format or error message
  # Returns {valid_tools, error_messages}
  defp resolve_tool_calls(tool_calls, tool_map, routine_id) do
    tool_calls
    |> Enum.map(fn %{id: id, name: name, input: input} ->
      case Map.get(tool_map, name) do
        {module, function} ->
          {:ok, %{
            id: id,
            module: module,
            function: function,
            input: input
          }}

        nil ->
          # Tool not found - create error message to send back to agent
          available_tools = Map.keys(tool_map) |> Enum.sort() |> Enum.join(", ")
          error_message = "Error: Tool '#{name}' not found. Available tools: #{available_tools}"
          {:error, id, error_message, routine_id}
      end
    end)
    |> Enum.split_with(fn
      {:ok, _} -> true
      {:error, _, _, _} -> false
    end)
    |> then(fn {valid, errors} ->
      # Extract valid tools from {:ok, tool} tuples
      valid_tools = Enum.map(valid, fn {:ok, tool} -> tool end)

      # Convert errors to tool_result messages
      error_messages = Enum.map(errors, fn {:error, id, message, routine_id} ->
        build_error_tool_result(id, message, routine_id)
      end)

      {valid_tools, error_messages}
    end)
  end

  # Build a tool_result message with error content
  defp build_error_tool_result(tool_id, error_message, routine_id) do
    MessageBuilder.build_tool_result_message(
      tool_id,
      error_message,
      [source: :tool_result, routine_id: routine_id, is_error: true]
    )
  end
end
