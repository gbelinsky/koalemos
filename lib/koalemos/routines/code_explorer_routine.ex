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
          ## Code Explorer

          You are exploring a codebase to understand its structure and answer questions.

          **Your Working Directory:** <%= Map.get(@context, :working_directory, "current directory") %>

          **Currently Open Items:** <%=
            lens_state = Map.get(@context, :lens_state, %{})
            open_items = Map.get(lens_state, :open_items, %{})
            if open_items == %{}, do: "none", else: open_items |> Map.keys() |> Enum.sort() |> Enum.join(", ")
          %>

          ## Guidelines

          1. **Start broad** - Open the root directory first to see project structure
          2. **Follow the trail** - Open related files to understand connections
          3. **Stay focused** - Close files you no longer need to keep context clean
          4. **Be thorough** - Check multiple files when investigating a concept

          ## When Answering Questions

          - Open relevant files before answering
          - Quote specific line numbers when referencing code
          - Close files when done to manage your working set

          Respond naturally to the user's questions while using tools to explore.
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
