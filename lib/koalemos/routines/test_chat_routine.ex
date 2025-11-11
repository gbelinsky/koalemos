defmodule Koalemos.Routines.TestChatRoutine do
  @moduledoc """
  A simple test chat routine that demonstrates the basic agent loop.

  Loop: ChatUserInput → LensRendering → LLMRequest → ResponseParsing → loop back

  The routine:
  1. Waits for user input
  2. Renders context from TestLens
  3. Makes an LLM request
  4. Parses the response
  5. Loops back to wait for more user input

  Initial context should include:
  - llm_provider (default: "anthropic")
  - model (default: "claude-3-5-haiku-20241022")
  - max_tokens (default: 2000)
  - temperature (default: 0.7)
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.{LensRendering, LLMRequest, ResponseParsing}

  @doc """
  Returns the routine definition for the test chat workflow.
  """
  def routine_definition do
    %{
      # Start by waiting for user input
      start: %{
        type: ChatUserInput,
        transitions: [{:render_lens, :always}]
      },

      # Get context from lenses
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
        transitions: [{:start, :always}]
      }
    }
  end

  @doc """
  Simple condition that always returns true.
  """
  def check_condition(:always, _context), do: true

  @doc """
  Returns default initial context for the routine.
  Engine will auto-call this and merge with user-provided context.
  """
  def initial_context do
    %{
      messages: [],
      lenses: ["Koalemos.Lenses.TestLensScreenshot"],
      llm_provider: "anthropic",
      llm_model: "claude-haiku-4-5",
      max_tokens: 2000,
      temperature: 0.7
    }
  end
end
