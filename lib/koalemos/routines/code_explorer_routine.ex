defmodule Koalemos.Routines.CodeExplorerRoutine do
  @moduledoc """
  A code exploration routine that uses FileNavigationLens for understanding codebases.

  This routine demonstrates the TemplatedSemanticAgent pattern with configurable lenses.
  The agent can:
  - Navigate directories and open files
  - Read and understand code structure
  - Answer questions about the codebase
  - Build mental models by exploring related files

  ## Configuration

  The routine uses FileNavigationLens by default. The working_directory can be
  set in context to scope exploration to a specific path.

  ## Example Usage in Inspector

  1. Start with CodeExplorerRoutine
  2. Ask: "What's the structure of this project?"
  3. Agent will use open/close tools to explore and answer

  ## Phases

  1. **explore** - Interactive exploration with file navigation tools
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.TemplatedSemanticAgent

  def start, do: :user_input

  def routine_definition do
    %{
      # Wait for user input
      user_input: %{
        type: ChatUserInput,
        transitions: [{:explore, :always}]
      },

      # Main exploration phase with file navigation
      explore: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          You are a code explorer. Use the file navigation tools to explore the codebase
          and answer questions. Open files and directories to see their contents, close
          them when no longer needed.

          Working directory: <%= Map.get(@context, :working_directory, ".") %>
          """,
          lenses: [
            "Koalemos.Lenses.FileNavigationLens"
          ]
        },
        transitions: [{:user_input, :always}]
      }
    }
  end

  def check_condition(:always, _context), do: true

  def initial_context do
    %{
      messages: [],
      lenses: [],
      working_directory: File.cwd!(),
      llm_provider: "anthropic",
      llm_model: "claude-sonnet-4-5",
      max_tokens: 4096,
      temperature: 0.3
    }
  end
end
