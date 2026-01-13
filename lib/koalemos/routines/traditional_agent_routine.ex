defmodule Koalemos.Routines.TraditionalAgentRoutine do
  @moduledoc """
  A traditional coding agent routine using TraditionalAgentLens for comparison testing.

  This routine provides opencode-compatible tools (Read, Write, Edit, Glob, Grep, Bash, TodoWrite)
  with minimal context injection - the agent must explicitly read files to know their state.

  ## Purpose

  Enables fair comparison between traditional agent approaches and Koalemos's dynamic
  context approaches. The agent has the same capabilities as opencode/Claude Code.

  ## Tools Available

  - **Read** - Read file contents with line numbers
  - **Write** - Create or overwrite files
  - **Edit** - Exact string replacement in files
  - **Glob** - Find files by pattern
  - **Grep** - Search file contents with regex
  - **Bash** - Execute shell commands
  - **TodoWrite** - Manage task list for tracking progress

  ## Example Usage

  1. Start with TraditionalAgentRoutine
  2. Ask: "Add a new function to lib/my_module.ex"
  3. Agent will use Read to see the file, Edit to modify it, etc.
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.TemplatedSemanticAgent

  def start, do: :user_input

  def routine_definition do
    %{
      user_input: %{
        type: ChatUserInput,
        transitions: [{:agent, :always}]
      },

      agent: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: "",
          lenses: [
            ["Koalemos.Lenses.TraditionalAgentLens", %{
              working_directory: "<%= Map.get(@context, :working_directory, \".\") %>",
              system_prompt: "<%= Map.get(@context, :system_prompt, \"\") %>"
            }]
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
      system_prompt: "You are a software engineer. Help with coding tasks using the available tools.",
      llm_provider: "anthropic",
      llm_model: "claude-sonnet-4-5",
      max_tokens: 8192,
      temperature: 0.3
    }
  end
end
