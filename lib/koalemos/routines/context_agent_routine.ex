defmodule Koalemos.Routines.ContextAgentRoutine do
  @moduledoc """
  A context-focused coding agent routine using ContextAgentLens for comparison testing.

  This routine provides the same coding tools as TraditionalAgentRoutine, but with
  automatic context management. Files explicitly opened by the agent appear in context
  every turn, and modifications are automatically reflected in context.

  ## Paradigm Comparison

  **Traditional Agent**: Must `Read` file before `Edit` (content in messages)
  **Context Agent**: Must `Open` file before `Edit` (content in context)

  Both routines provide identical coding capabilities:
  - Traditional: Agent must Read files every time to see content
  - Context-focused: Agent opens files once, content stays in context and auto-updates

  ## Purpose

  Enables fair comparison between traditional "read every time" approaches and
  context-focused "open once, track changes" approaches.

  ## Tools Available

  - **open** - Add file/directory to working context
  - **close** - Remove file/directory from context
  - **write** - Create/overwrite files (auto-opens new files)
  - **edit** - Exact string replacement (only works on open files, auto-refreshes)
  - **glob** - Find files by pattern
  - **grep** - Search file contents with regex
  - **bash** - Execute shell commands
  - **todo_write** - Manage task list

  ## Example Usage

  1. Start with ContextAgentRoutine
  2. Ask: "Add a new function to lib/my_module.ex"
  3. Agent will use Glob to find the file, Open to view it, Edit to modify it
  4. File content stays visible in context and auto-updates after edits
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
            ["Koalemos.Lenses.ContextAgentLens", %{
              working_directory: "<%= Map.get(@context, :working_directory, \".\") %>",
              system_prompt: "<%= Map.get(@context, :system_prompt, \"\") %>",
              max_open_files: 25
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
      system_prompt: """
      You are a software engineer with context-aware file management.

      ## File Management Strategy

      - Use 'open' to add files/directories to your working context
      - Open files stay visible and auto-update after edits
      - Use 'close' to remove files when done
      - Maximum 10 open files at once

      ## Tool Workflow

      1. **Explore**: Use Glob/Grep to find relevant files
      2. **Open**: Add files to context with 'open' (content appears automatically)
      3. **Edit**: Modify open files with 'edit' (only works on open files)
      4. **Write**: Create new files with 'write' (auto-opens them)
      5. **Close**: Remove files from context when finished

      ## Important

      - Unlike traditional agents, you don't need to Read files repeatedly
      - Open files are always visible in your context
      - After editing, the updated content appears automatically (no re-reading needed)
      - You must 'open' files before you can 'edit' them (parallel to "Read before Edit")

      Help with coding tasks using the available tools.
      """,
      llm_provider: "anthropic",
      llm_model: "claude-sonnet-4-5",
      max_tokens: 32000,
      temperature: 0.3
    }
  end
end
