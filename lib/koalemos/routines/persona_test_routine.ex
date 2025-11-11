defmodule Koalemos.Routines.PersonaTestRoutine do
  @moduledoc """
  A test routine for experimenting with PersonaLens configurations.

  Loop: ChatUserInput → LensRendering → LLMRequest → ResponseParsing → loop back

  The routine:
  1. Waits for user input
  2. Renders context from PersonaLens with configured dimensions
  3. Makes an LLM request
  4. Parses the response
  5. Loops back to wait for more user input

  ## Persona Configuration

  The routine allows testing different dimensional persona configurations by
  passing lens config at initialization. Default configuration provides a
  professional, balanced technical expert.

  ## Example Usage

  ```elixir
  # Professional technical expert (default)
  Koalemos.Engine.start_routine(
    "Koalemos.Routines.PersonaTestRoutine",
    %{}
  )

  # Friendly UX designer with storytelling style
  Koalemos.Engine.start_routine(
    "Koalemos.Routines.PersonaTestRoutine",
    %{
      lenses: [
        ["Koalemos.Lenses.PersonaLens", %{
          tone: :friendly,
          expertise: [:creative, :ux],
          style: :storytelling
        }]
      ]
    }
  )

  # Empathetic business analyst with detailed explanations
  Koalemos.Engine.start_routine(
    "Koalemos.Routines.PersonaTestRoutine",
    %{
      lenses: [
        ["Koalemos.Lenses.PersonaLens", %{
          tone: :empathetic,
          expertise: [:business, :analytical],
          style: :detailed
        }]
      ]
    }
  )
  ```

  Initial context should include:
  - llm_provider (default: "anthropic")
  - model (default: "claude-haiku-4-5")
  - max_tokens (default: 2000)
  - temperature (default: 0.7)
  - lenses (default: PersonaLens with professional/technical/balanced)
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.{LensRendering, LLMRequest, ResponseParsing}

  @doc """
  Returns the routine definition for the persona test workflow.
  """
  def routine_definition do
    %{
      # Start by waiting for user input
      start: %{
        type: ChatUserInput,
        transitions: [{:render_lens, :always}]
      },

      # Get context from PersonaLens
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

  Default persona: Professional tone, technical expertise, balanced style
  """
  def initial_context do
    %{
      messages: [],
      lenses: [
        ["Koalemos.Lenses.PersonaLens", %{
          tone: :professional,
          expertise: [:technical],
          style: :balanced
        }]
      ],
      llm_provider: "anthropic",
      llm_model: "claude-haiku-4-5",
      max_tokens: 2000,
      temperature: 0.7
    }
  end
end
