defmodule Koalemos.Routines.PlayRoutine do
  @moduledoc """
  V4 tight interaction loop for playing with wireframe.

  Clean V4 implementation using StateServer architecture:
  - Uses WireframeEditor lens
  - StateServer is single source of truth (inherited from parent)
  - No lens_state in context

  ## Purpose

  Provides a focused interaction mode where users can:
  - Play games implemented in the wireframe
  - Test and interact with wireframe features conversationally
  - Get immediate feedback from the agent

  ## Flow

  Simple two-step loop:
  1. **start** - Agent responds and interacts with wireframe
  2. **await_input** - Wait for user input
  3. Loop back to start

  ## Exit Mechanism

  The agent uses semantic transition to exit when it detects:
  - User wants to stop playing
  - User wants to make changes to the wireframe
  - Game is over

  This exits the tight loop and returns control to the parent routine.
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.TemplatedSemanticAgent

  def start, do: :start

  def routine_definition do
    %{
      # Agent interaction - respond and interact with wireframe
      start: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          You're in INTERACTIVE PLAY MODE - a tight loop for playing games or testing features.

          Respond to the user's request and interact with the wireframe:
          - Play games implemented in the wireframe
          - Test interactive features using trigger_interaction
          - Explore functionality and show results
          - Use sequential_thinking to plan your interactions

          AVAILABLE TOOLS:
          - trigger_interaction: Test clicks, form inputs, etc.
          - read_dom: Check current state
          - capture_screenshot: Show visual state
          - sequential_thinking: Plan and explain your actions

          AFTER RESPONDING - DECIDE NEXT STEP:
          Watch for signs the user wants to exit:
          - "let's change..." / "modify..." / "update..."
          - "go back" / "done playing" / "stop"
          - Requests that require editing the wireframe
          - The game being over

          If user wants to exit or make changes:
          → use choose_transition to exit play mode and return to parent routine

          If continuing to play:
          → just finish your turn normally

          You are in a LOOP - after responding, decide whether to continue or exit.
          """,
          lenses: [
            "Koalemos.Lenses.WireframeEditor",
            "Koalemos.Lenses.SequentialThinking",
            "Koalemos.Lenses.SemanticTransition"
          ]
        },
        transitions: [
          {:end, "User wants to stop playing, make changes, or exit interactive mode"},
          {:await_input, :always}
        ]
      },

      # Wait for next user input to continue the loop
      await_input: %{
        type: ChatUserInput,
        transitions: [{:start, :always}]
      }
    }
  end

  def check_condition(:always, _context), do: true

  def initial_context do
    %{
      messages: [],
      lenses: [
        "Koalemos.Lenses.WireframeEditor",
        "Koalemos.Lenses.SequentialThinking"
      ]
    }
  end

  def setup(_routine_config, _state) do
    {:ok, []}
  end
end
