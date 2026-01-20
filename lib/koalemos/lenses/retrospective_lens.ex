defmodule Koalemos.Lenses.RetrospectiveLens do
  @moduledoc """
  RetrospectiveLens provides context from a completed routine for analysis.

  This is a context-only lens (no tools) that loads and formats the conversation
  history from a source routine, making it available for retrospective analysis.

  ## Purpose

  Enables an agent to analyze a completed task and extract insights, learnings,
  and prerequisites that would have been valuable to know beforehand.

  ## Configuration

  ```elixir
  lenses: [
    ["Koalemos.Lenses.RetrospectiveLens", %{
      source_routine_id: "task-123"  # Can be literal string or EEx template
    }]
  ]
  ```

  The `source_routine_id` can be:
  - A literal string: `"task-123"`
  - An EEx template: `"<%= Map.get(@context, :source_routine_id) %>"`

  ## Context Provided

  - Source routine metadata (module, status, step count)
  - Complete conversation history (all messages)
  - Rendered context snapshots (what the agent saw at each turn)
  - Tool calls and results (if any)

  ## Usage in Routine

  ```elixir
  def initial_context do
    %{
      source_routine_id: "completed-task-123",
      lenses: [
        ["Koalemos.Lenses.RetrospectiveLens", %{
          source_routine_id: "<%= Map.get(@context, :source_routine_id) %>"
        }]
      ]
    }
  end
  ```
  """

  require Logger

  @doc """
  Provide context blocks showing the source routine's history.

  Returns formatted blocks containing:
  1. Metadata about the source routine
  2. Complete conversation history
  3. Context snapshots (if available)
  """
  def provide_context(state, config \\ %{}) do
    # Evaluate config templates with context
    evaluated_config = evaluate_config(config, state.context)
    
    # Get source_routine_id from config (preferred) or context (fallback)
    source_routine_id = 
      Map.get(evaluated_config, :source_routine_id) || 
      Map.get(state.context, :source_routine_id)

    unless source_routine_id do
      return_error("source_routine_id not provided in config or context")
    end

    # Load the source routine
    case Koalemos.EngineManager.get_routine(source_routine_id) do
      {:ok, routine_info} ->
        build_context_blocks(routine_info, source_routine_id)

      {:error, :not_found} ->
        return_error("Source routine not found: #{source_routine_id}")

      {:error, reason} ->
        return_error("Failed to load routine: #{inspect(reason)}")
    end
  end

  # Build context blocks from routine info
  defp build_context_blocks(routine_info, source_routine_id) do
    [
      build_header_block(routine_info, source_routine_id),
      build_metadata_block(routine_info),
      build_conversation_block(routine_info),
      build_context_snapshot_block(routine_info)
    ]
    |> Enum.reject(&is_nil/1)
  end

  # Header block
  defp build_header_block(_routine_info, source_routine_id) do
    %{
      type: "text",
      text: """
      # RETROSPECTIVE ANALYSIS

      You are analyzing a completed task to extract insights and learnings.

      **IMPORTANT:** The conversation history below is NOT your conversation.
      You are an external observer analyzing it to identify:
      - What was learned during the task
      - What prerequisites would have helped
      - What patterns emerged
      - Key recommendations for similar tasks

      Source Routine ID: `#{source_routine_id}`

      ---
      """
    }
  end

  # Metadata block
  defp build_metadata_block(routine_info) do
    %{
      type: "text",
      text: """
      ## Task Metadata

      - **Routine Module:** #{inspect(routine_info.module)}
      - **Status:** #{routine_info.status}
      - **Current Step:** #{routine_info.current_step}
      - **Message Count:** #{length(routine_info.messages)}
      - **Execution Stack Depth:** #{length(routine_info.execution_stack)}

      ---
      """
    }
  end

  # Conversation history block
  defp build_conversation_block(routine_info) do
    formatted_messages = format_messages(routine_info.messages)

    %{
      type: "text",
      text: """
      ## Complete Conversation History

      #{formatted_messages}

      ---
      """
    }
  end

  # Context snapshot block (if lens_state contains rendered contexts)
  defp build_context_snapshot_block(routine_info) do
    lens_state = Map.get(routine_info.context, :lens_state, %{})
    context_snapshots = Map.get(lens_state, :context_snapshots, [])

    if Enum.empty?(context_snapshots) do
      nil
    else
      formatted_snapshots = format_context_snapshots(context_snapshots)

      %{
        type: "text",
        text: """
        ## Context Snapshots

        These are snapshots of what context was rendered for the agent at various points:

        #{formatted_snapshots}

        ---
        """
      }
    end
  end

  # Format messages for display
  defp format_messages(messages) do
    messages
    |> Enum.with_index(1)
    |> Enum.map(fn {msg, idx} -> format_message(msg, idx) end)
    |> Enum.join("\n\n")
  end

  defp format_message(%{role: role, content: content}, idx) when is_binary(content) do
    """
    ### Message #{idx} - #{String.upcase(role)}

    #{content}
    """
  end

  defp format_message(%{role: role, content: content}, idx) when is_list(content) do
    formatted_content = 
      content
      |> Enum.map(&format_content_block/1)
      |> Enum.join("\n\n")

    """
    ### Message #{idx} - #{String.upcase(role)}

    #{formatted_content}
    """
  end

  defp format_message(msg, idx) do
    """
    ### Message #{idx} - UNKNOWN FORMAT

    #{inspect(msg, pretty: true)}
    """
  end

  # Format individual content blocks
  defp format_content_block(%{type: "text", text: text}) do
    text
  end

  defp format_content_block(%{type: "tool_use", id: id, name: name, input: input}) do
    """
    **[TOOL CALL: #{name}]**
    Tool ID: `#{id}`
    Input:
    ```json
    #{Jason.encode!(input, pretty: true)}
    ```
    """
  end

  defp format_content_block(%{type: "tool_result", tool_use_id: id, content: content}) 
    when is_binary(content) do
    """
    **[TOOL RESULT]**
    Tool ID: `#{id}`
    Result:
    ```
    #{content}
    ```
    """
  end

  defp format_content_block(%{type: "tool_result", tool_use_id: id, content: content}) 
    when is_list(content) do
    formatted = Enum.map_join(content, "\n", fn
      %{type: "text", text: text} -> text
      other -> inspect(other, pretty: true)
    end)

    """
    **[TOOL RESULT]**
    Tool ID: `#{id}`
    Result:
    ```
    #{formatted}
    ```
    """
  end

  defp format_content_block(block) do
    """
    **[COMPLEX CONTENT BLOCK]**
    ```
    #{inspect(block, pretty: true, limit: :infinity)}
    ```
    """
  end

  # Format context snapshots
  defp format_context_snapshots(snapshots) do
    snapshots
    |> Enum.with_index(1)
    |> Enum.map(fn {snapshot, idx} ->
      """
      ### Snapshot #{idx}

      #{snapshot}
      """
    end)
    |> Enum.join("\n\n")
  end

  # Error handling
  defp return_error(message) do
    Logger.warning("[RetrospectiveLens] #{message}")

    [
      %{
        type: "text",
        text: """
        # RETROSPECTIVE ANALYSIS ERROR

        #{message}

        Please ensure:
        1. source_routine_id is provided in lens config or context
        2. The source routine exists and is accessible
        3. The routine has completed or has messages to analyze
        """
      }
    ]
  end

  # EEx template evaluation helpers
  # These allow dynamic configuration using context values like:
  # source_routine_id: "<%= Map.get(@context, :source_routine_id) %>"

  defp evaluate_config(config, context) when is_map(config) do
    Map.new(config, fn {key, value} ->
      {key, evaluate_template_value(value, context)}
    end)
  end

  defp evaluate_config(config, _context), do: config

  # Evaluate a single value - recursively handle strings, maps, and lists
  defp evaluate_template_value(value, context) when is_binary(value) do
    # Check if string contains EEx markers
    if String.contains?(value, "<%") do
      try do
        assigns = %{context: context}
        EEx.eval_string(value, assigns: assigns)
      rescue
        error ->
          Logger.warning(
            "Failed to evaluate EEx template in RetrospectiveLens config: #{Exception.message(error)}"
          )

          # Return original value on failure
          value
      end
    else
      value
    end
  end

  defp evaluate_template_value(value, context) when is_map(value) do
    evaluate_config(value, context)
  end

  defp evaluate_template_value(value, context) when is_list(value) do
    Enum.map(value, &evaluate_template_value(&1, context))
  end

  defp evaluate_template_value(value, _context), do: value
end
