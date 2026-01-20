defmodule Koalemos.Routines.CodeAnalysisRoutine do
  @moduledoc """
  A code analysis routine that produces structured output.

  Demonstrates StructuredResponseAgent - the agent explores with file navigation
  tools, then calls `respond` with structured analysis. The result is captured
  to context and available for subsequent turns.

  ## Configuration

  Uses FileNavigationLens for exploration. The working_directory can be
  set in context to scope analysis to a specific path.

  ## Example Usage

  1. Start with CodeAnalysisRoutine
  2. Ask: "Analyze this project"
  3. Agent explores files, then provides structured analysis
  4. Result stored in context[:analysis]
  """

  alias Koalemos.Steps.User.ChatUserInput
  alias Koalemos.Steps.Agent.StructuredResponseAgent

  def start, do: :user_input

  def routine_definition do
    %{
      user_input: %{
        type: ChatUserInput,
        transitions: [{:analyze, :always}]
      },

      analyze: %{
        type: StructuredResponseAgent,
        config: %{
          template: """
          Analyze the codebase and provide a structured summary. Use the file
          navigation tools to explore, then call respond with your analysis.

          Working directory: <%= Map.get(@context, :working_directory, ".") %>
          """,
          output_key: :analysis,
          schema: %{
            summary: %{type: :string, description: "Brief project summary (1-2 sentences)"},
            language: %{type: :string, description: "Primary programming language"},
            framework: %{type: :string, description: "Main framework or runtime", required: false},
            complexity: %{type: :enum, values: ["low", "medium", "high"]},
            key_files: %{
              type: :array,
              items: :string,
              description: "Most important files to understand the project"
            },
            notes: %{type: :string, description: "Additional observations", required: false}
          },
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
