defmodule Koalemos.Routines.ThinkingTestRoutine do
  @moduledoc """
  Test routine for SequentialThinking lens.

  Provides a chat interface with the sequential_thinking tool enabled,
  allowing manual testing of step-by-step reasoning.

  Loop: ChatUserInput → LensRendering → LLMRequest → ResponseParsing → loop back

  ## Usage

  ```elixir
  # Start routine with SequentialThinking enabled
  Koalemos.Engine.start_routine(
    "thinking-test",
    Koalemos.Routines.ThinkingTestRoutine,
    %{}
  )
  ```

  ## Testing Tips

  Try complex multi-step problems:
  - "How would you design a distributed caching system?"
  - "Break down the steps to migrate a monolith to microservices"
  - "Plan a refactoring strategy for a legacy codebase"

  Watch for:
  - Step-by-step reasoning in tool calls
  - Revisions when reconsidering previous thoughts
  - Current chain showing in context
  - Brief tool results (no thought echo)
  """

  alias Koalemos.Steps.User.ChatUserInput

  alias Koalemos.Steps.Agent.{
    ToolSchema,
    LensRendering,
    LLMRequest,
    ResponseParsing,
    ToolLookup,
    ToolExecution
  }

  @doc """
  Returns the routine definition.

  Full agent loop with tool execution:
  start (ChatUserInput) → build_tool_schema → render_lens → llm_request → parse_response
    → (if tools) tool_lookup → tool_execution → (back to start for next user input)
    → (if no tools) back to start for next user message
  """
  def routine_definition do
    %{
      # Wait for user input (main loop entry point)
      start: %{
        type: ChatUserInput,
        transitions: [{:build_tool_schema, :always}]
      },

      # Build tool schema (runs each time but results are the same)
      build_tool_schema: %{
        type: ToolSchema,
        transitions: [{:render_lens, :always}]
      },

      # Get context from SequentialThinking lens
      render_lens: %{
        type: LensRendering,
        transitions: [{:llm_request, :always}]
      },

      # Make LLM request with messages and lens context
      llm_request: %{
        type: LLMRequest,
        transitions: [{:parse_response, :always}]
      },

      # Parse LLM response and add to messages
      parse_response: %{
        type: ResponseParsing,
        transitions: [
          {:tool_lookup, :when_has_tool_calls},
          {:start, :when_no_tool_calls}
        ]
      },

      # Resolve tool calls to executable format
      tool_lookup: %{
        type: ToolLookup,
        transitions: [{:tool_execution, :always}]
      },

      # Execute tools one at a time
      tool_execution: %{
        type: ToolExecution,
        transitions: [
          {:tool_execution, :when_has_more_tools},
          {:build_tool_schema, :when_tools_complete}
        ]
      }
    }
  end

  @doc """
  Condition check functions for routine transitions.
  """
  def check_condition(:always, _context), do: true

  def check_condition(:when_has_tool_calls, context) do
    tool_calls = Map.get(context, :tool_calls, [])
    length(tool_calls) > 0
  end

  def check_condition(:when_no_tool_calls, context) do
    tool_calls = Map.get(context, :tool_calls, [])
    length(tool_calls) == 0
  end

  def check_condition(:when_has_more_tools, context) do
    remaining = Map.get(context, :to_execute, [])
    length(remaining) > 0
  end

  def check_condition(:when_tools_complete, context) do
    remaining = Map.get(context, :to_execute, [])
    length(remaining) == 0
  end

  @doc """
  Returns default initial context for the routine.
  """
  def initial_context do
    %{
      messages: [],
      lenses: ["Koalemos.Lenses.SequentialThinking"],
      llm_provider: "anthropic",
      llm_model: "claude-haiku-4-5",
      max_tokens: 64000,
      temperature: 0.7
    }
  end
end
