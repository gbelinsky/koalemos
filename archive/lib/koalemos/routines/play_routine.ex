defmodule Koalemos.Routines.PlayRoutine do
  @moduledoc """
  Tight interaction loop for playing with wireframe without routing overhead.

  This routine provides a focused interaction mode where users can:
  - Play games implemented in the wireframe
  - Test and interact with wireframe features conversationally
  - Get immediate feedback from the agent

  ## Architecture

  Simple two-step loop:
  1. **start** - User provides input
  2. **interact** - Agent responds and uses tools (readonly + trigger_interaction)
  3. Loop back to start

  ## Exit Mechanism

  The agent uses workflow_transition("exit_play") when it detects the user wants to:
  - Stop playing/interacting
  - Make changes to the wireframe
  - Return to the main design flow

  This exits the tight loop and returns control to the parent routine.

  ## Tools Available

  - Readonly WireframeEditor (read_dom, capture_screenshot)
  - trigger_interaction (test interactions)
  - SequentialThinking (for planning)
  - WorkflowTransition (for exiting)

  No modification tools - this is for interaction and testing only.

  ## Example Flow

  ```
  User: "Let's play tic-tac-toe"
    ↓
  start → agent clicks cells, shows board state, decides to continue
    ↓
  await_input → User: "click top-left"
    ↓
  start → agent uses trigger_interaction, shows result, decides to continue
    ↓
  await_input → User: "actually, let's make the board bigger"
    ↓
  start → agent detects modification request
        → choose_transition(:end, "User wants to modify board")
    ↓
  (exits to parent routine's show_result step)
  ```
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.TemplatedSemanticAgent

  @doc """
  Returns the routine definition with tight interaction loop.

  Loop:
  start (agent responds/interacts) → decide to continue or exit → await_input (if continuing) → start
  Exit: via choose_transition to :end when user wants to stop
  """
  def routine_definition do
    %{
      # Agent interaction first - respond and interact with wireframe
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
            "Koalemos.Lenses.WireframeEditorV4",
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

  @doc """
  Condition check function - always returns true.
  """
  def check_condition(:always, _context), do: true

  @doc """
  Returns the start step for the routine.
  """
  def start, do: :start
end
