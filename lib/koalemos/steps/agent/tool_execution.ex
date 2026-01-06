defmodule Koalemos.Steps.Agent.ToolExecution do
  @moduledoc """
  ToolExecution step executes one tool call and manages the execution queue.

  Processes one tool at a time (consume pattern), adds result to messages,
  updates the to_execute queue. Supports lens state updates from tools.

  ## Context Input
  - to_execute: List of %{id, module, function, input} from ToolLookupNode
  - messages: Conversation history
  - lens_state: (optional) State maintained by lenses

  ## Context Output
  - messages: Updated with tool result (appended)
  - to_execute: Queue with processed tool removed
  - lens_state: (optional) Updated if tool returns lens updates

  ## Tool Result Formats

  Tools can return results in multiple formats:
  - Simple string: `"result text"`
  - With lens updates: `{"result text", [lens_key: value]}`
  - With metadata: `{"result text", [lens_key: value], %{metadata}}`
  - Content blocks: `{[{:text, "result"}, {:image, base64, type}], lens_updates}`
  - Content blocks with metadata: `{[{:text, "result"}, {:image, base64, type}], lens_updates, metadata}`

  Content blocks allow tools to return rich results including images.

  ## Example

  ```elixir
  execute_tool: %{
    type: Koalemos.Steps.Agent.ToolExecution,
    transitions: [
      {:execute_tool, fn state -> state.context[:to_execute] != [] end},
      {:continue, :always}
    ]
  }
  ```
  """

  require Logger
  require Koalemos.Log
  alias Koalemos.Log

  @doc """
  Executes one tool from the queue.
  """
  def execute(_config, state) do
    case state.context[:to_execute] do
      [tool_call | remaining] ->
        # Add routine ID to context for tools that need it
        enhanced_context = Map.put(state.context, :routine_id, state.routine_id)

        # Execute single tool
        tool_result = execute_single_tool(tool_call, enhanced_context)

        {result, lens_updates, _metadata} = normalize_tool_result(tool_result)

        # Build tool result message from tool output
        tool_message = build_tool_result_message(tool_call.id, result, state.routine_id)

        Log.debug(:engine, "[ToolExecution] Appending tool_result for #{tool_call.id}")

        # Build diff - use append_to for messages
        diff = [
          append_to: %{messages: [tool_message]},
          add_or_update: %{to_execute: remaining}
        ]

        # Add lens updates if present
        final_diff =
          if lens_updates != [] do
            existing_lens_state = state.context[:lens_state] || %{}

            updated_lens_state =
              Enum.reduce(lens_updates, existing_lens_state, fn {key, value}, acc ->
                Map.put(acc, key, value)
              end)

            diff ++ [add_or_update: %{lens_state: updated_lens_state}]
          else
            diff
          end

        {:ok, final_diff}

      [] ->
        # No tools to execute - clean up empty queue
        {:ok, [remove: [:to_execute]]}

      nil ->
        {:error, "No tool calls found in context"}
    end
  end

  # Execute a single tool with error handling
  defp execute_single_tool(tool_call, context) do
    try do
      # Execute tool using module and function from ToolLookupNode
      if function_exported?(tool_call.module, tool_call.function, 2) do
        apply(tool_call.module, tool_call.function, [tool_call.input, context])
      else
        apply(tool_call.module, :execute, [tool_call.function, tool_call.input, context])
      end
    rescue
      error ->
        {"Tool execution failed: #{Exception.message(error)}", []}
    end
  end

  # Normalize different tool result formats to {result, lens_updates, metadata}
  defp normalize_tool_result(tool_result) do
    case tool_result do
      # Standard formats
      {result, lens_updates, metadata} when is_list(lens_updates) and is_map(metadata) ->
        {result, lens_updates, metadata}

      {result, lens_updates} when is_list(lens_updates) ->
        {result, lens_updates, %{}}

      result when is_binary(result) ->
        {result, [], %{}}

      # Handle {:ok, result} and {:error, reason} patterns
      {:ok, result} when is_binary(result) ->
        {result, [], %{}}

      {:ok, result} ->
        {inspect(result), [], %{}}

      {:error, reason} when is_binary(reason) ->
        {"Error: #{reason}", [], %{}}

      {:error, reason} ->
        {"Error: #{inspect(reason)}", [], %{}}

      # Catch-all for unexpected formats
      nil ->
        {"Tool returned nil", [], %{}}

      other ->
        {inspect(other), [], %{}}
    end
  end

  # Build a tool result message
  defp build_tool_result_message(tool_id, content, routine_id) do
    Koalemos.Utils.MessageBuilder.build_tool_result_message(
      tool_id,
      content,
      source: :tool_result,
      routine_id: routine_id
    )
  end
end
