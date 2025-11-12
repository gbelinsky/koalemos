defmodule Koalemos.Lenses.SequentialThinking do
  @moduledoc """
  SequentialThinking lens enables step-by-step reasoning with revision and branching.

  Based on Sequential Thinking MCP server by Anthropic, PBC
  Source: https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking
  License: MIT

  Adapted for Koalemos lens architecture and state management patterns

  Copyright (c) 2025 Anthropic, PBC

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

  ## Koalemos Adaptations

  - Uses Koalemos lens interface: `provide_context(state, config)` and `execute_tool(name, args, state)`
  - Context shows only current/active thinking chain (MVP scope)
  - Tool results are brief JSON (no thought text echo to reduce redundancy)
  - Lens state management follows Koalemos patterns (similar to screenshot integration)

  ## Tool

  Provides a single tool `sequential_thinking` that manages structured thought processes
  with support for revisions, branching, and dynamic adjustment of thinking steps.

  ### Parameters
  - `thought` (required): Your current thinking step
  - `next_thought_needed` (required): Whether another thought step is needed
  - `thought_number` (required): Current thought number (1-indexed)
  - `total_thoughts` (required): Estimated total thoughts needed (can be adjusted)
  - `is_revision` (optional): Boolean for revising previous thinking
  - `revises_thought` (optional): Which thought number is being reconsidered
  - `branch_from_thought` (optional): Branching point thought number
  - `branch_id` (optional): Branch identifier
  - `needs_more_thoughts` (optional): Signal more thoughts needed despite reaching limit

  ## Context Engineering

  Shows only the current/active thinking chain in context. When a new chain starts
  (thought_number == 1), previous chain is cleared from context. This keeps context
  focused and avoids showing stale reasoning.
  """

  require Logger

  @doc """
  Provide context blocks showing current thinking chain.

  Returns a text block with the current/active reasoning chain. When a new chain
  starts, previous chain is replaced.
  """
  def provide_context(state, _config \\ %{}) do
    lens_state = Map.get(state.context, :lens_state, %{})
    thought_history = Map.get(lens_state, :thought_history, [])

    if thought_history == [] do
      # No thoughts yet
      []
    else
      # Show current chain only (filter by detecting chain reset)
      current_chain = get_current_chain(thought_history)

      chain_text =
        Enum.map_join(current_chain, "\n", fn thought ->
          prefix = if thought.is_revision, do: "🔄", else: ""
          "#{prefix}#{thought.thought_number}. #{thought.thought}"
        end)

      [
        %{
          type: "text",
          text: """
          ## Current Thinking Chain

          #{chain_text}

          #{if List.last(current_chain).next_thought_needed, do: "[Thinking continues...]", else: "[Thinking complete]"}
          """
        }
      ]
    end
  end

  @doc """
  Provide tool definitions for this lens.

  Returns list of {module, tool_atom} tuples for ToolSchema step.

  Config parameter is accepted for consistency with other lenses but not used.
  Sequential thinking is always available and non-destructive.
  """
  def tools(_config \\ %{}) do
    [{__MODULE__, :sequential_thinking}]
  end

  @doc """
  Provide tool schema for sequential_thinking tool.
  """
  def info(:sequential_thinking) do
    %{
      name: "sequential_thinking",
      description: """
      A detailed tool for dynamic and reflective problem-solving through thoughts. This tool helps analyze problems through a flexible thinking process that can adapt and evolve. Each thought can build on, question, or revise previous insights as understanding deepens.

      When to use this tool:
      - Breaking down complex problems into steps
      - Planning and design with room for revision
      - Analysis that might need course correction
      - Problems where the full scope might not be clear initially
      - Problems that require a multi-step solution
      - Tasks that need to maintain context over multiple steps
      - Situations where irrelevant information needs to be filtered out

      Key features:
      - You can adjust total_thoughts up or down as you progress
      - You can question or revise previous thoughts
      - You can add more thoughts even after reaching what seemed like the end
      - You can express uncertainty and explore alternative approaches
      - Not every thought needs to build linearly - you can branch or backtrack

      Parameters explained:
      - thought: Your current thinking step
      - next_thought_needed: True if you need more thinking, even if at what seemed like the end
      - thought_number: Current number in sequence (can go beyond initial total if needed)
      - total_thoughts: Current estimate of thoughts needed (can be adjusted up/down)
      - is_revision: A boolean indicating if this thought revises previous thinking
      - revises_thought: If is_revision is true, which thought number is being reconsidered
      - branch_from_thought: If branching, which thought number is the branching point
      - branch_id: Identifier for the current branch (if any)
      - needs_more_thoughts: If reaching end but realizing more thoughts needed
      """,
      input_schema: %{
        type: "object",
        properties: %{
          thought: %{
            type: "string",
            description: "Your current thinking step"
          },
          next_thought_needed: %{
            type: "boolean",
            description: "Whether another thought step is needed"
          },
          thought_number: %{
            type: "integer",
            description: "Current thought number (numeric value, e.g., 1, 2, 3)",
            minimum: 1
          },
          total_thoughts: %{
            type: "integer",
            description: "Estimated total thoughts needed (numeric value, e.g., 5, 10)",
            minimum: 1
          },
          is_revision: %{
            type: "boolean",
            description: "Whether this revises previous thinking"
          },
          revises_thought: %{
            type: "integer",
            description: "Which thought is being reconsidered",
            minimum: 1
          },
          branch_from_thought: %{
            type: "integer",
            description: "Branching point thought number",
            minimum: 1
          },
          branch_id: %{
            type: "string",
            description: "Branch identifier"
          },
          needs_more_thoughts: %{
            type: "boolean",
            description: "If more thoughts are needed"
          }
        },
        required: ["thought", "next_thought_needed", "thought_number", "total_thoughts"]
      }
    }
  end

  @doc """
  Execute the sequential_thinking tool.

  Returns {:ok, result, lens_updates} where:
  - result: Text message with progress indication
  - lens_updates: Updated thought_history and branches for lens_state
  """
  def execute(:sequential_thinking, args, context) do
    try do
      validated_input = validate_thought_data(args)

      # Adjust total_thoughts if thought_number exceeds it
      validated_input =
        if validated_input.thought_number > validated_input.total_thoughts do
          %{validated_input | total_thoughts: validated_input.thought_number}
        else
          validated_input
        end

      # Get current state from context
      lens_state = Map.get(context, :lens_state, %{})
      thought_history = Map.get(lens_state, :thought_history, [])
      branches = Map.get(lens_state, :branches, %{})

      # Add to thought history
      updated_history = thought_history ++ [validated_input]

      # Handle branching
      updated_branches =
        if validated_input.branch_from_thought && validated_input.branch_id do
          branch_thoughts = Map.get(branches, validated_input.branch_id, [])
          Map.put(branches, validated_input.branch_id, branch_thoughts ++ [validated_input])
        else
          branches
        end

      # Result with explicit next action guidance
      result_text =
        if validated_input.next_thought_needed do
          "Thought #{validated_input.thought_number}/#{validated_input.total_thoughts} recorded. Continue with next thought."
        else
          "Thought #{validated_input.thought_number}/#{validated_input.total_thoughts} recorded. Thought process complete."
        end

      # Return with lens_state updates (no :ok atom - ToolExecution handles wrapping)
      {result_text,
       [
         thought_history: updated_history,
         branches: updated_branches
       ]}
    rescue
      error ->
        Logger.error("[SequentialThinking] Tool execution failed: #{Exception.message(error)}")
        "Thinking tool failed: #{Exception.message(error)}"
    end
  end

  def execute(tool_name, _args, _state) do
    "Unknown tool: #{inspect(tool_name)}"
  end

  # Private helper functions

  # Get current chain from thought history
  # A new chain starts when thought_number == 1
  defp get_current_chain(thought_history) do
    # Find last occurrence of thought_number == 1
    last_chain_start =
      thought_history
      |> Enum.with_index()
      |> Enum.reverse()
      |> Enum.find(fn {thought, _idx} -> thought.thought_number == 1 end)

    case last_chain_start do
      {_thought, start_idx} ->
        Enum.drop(thought_history, start_idx)

      nil ->
        # No thought_number == 1 found, return all (shouldn't happen in normal use)
        thought_history
    end
  end

  defp validate_thought_data(params) do
    thought = params["thought"]

    unless is_binary(thought) && thought != "" do
      raise "Invalid thought: must be a non-empty string"
    end

    thought_number = params["thought_number"]

    unless is_integer(thought_number) && thought_number >= 1 do
      raise "Invalid thought_number: must be a positive integer"
    end

    total_thoughts = params["total_thoughts"]

    unless is_integer(total_thoughts) && total_thoughts >= 1 do
      raise "Invalid total_thoughts: must be a positive integer"
    end

    next_thought_needed = params["next_thought_needed"]

    unless is_boolean(next_thought_needed) do
      raise "Invalid next_thought_needed: must be a boolean"
    end

    %{
      thought: thought,
      thought_number: thought_number,
      total_thoughts: total_thoughts,
      next_thought_needed: next_thought_needed,
      is_revision: params["is_revision"] || false,
      revises_thought: params["revises_thought"],
      branch_from_thought: params["branch_from_thought"],
      branch_id: params["branch_id"],
      needs_more_thoughts: params["needs_more_thoughts"] || false
    }
  end
end
