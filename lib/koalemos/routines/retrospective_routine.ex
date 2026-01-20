defmodule Koalemos.Routines.RetrospectiveRoutine do
  @moduledoc """
  Analyzes a completed routine to extract learnings and insights.

  Takes a routine_id, loads its conversation history via RetrospectiveLens,
  and asks the agent to analyze what was learned that would have been valuable
  to know beforehand.

  ## Purpose

  Extract actionable knowledge from completed tasks:
  - What was learned during execution
  - What prerequisites would have helped
  - What patterns emerged (effective or ineffective)
  - Recommendations for similar future tasks

  ## Usage

  ```elixir
  {:ok, retro_id} = Koalemos.EngineManager.start_routine(
    Koalemos.Routines.RetrospectiveRoutine,
    %{source_routine_id: "completed-task-123"},
    "retro-#{System.unique_integer([:positive])}"
  )
  ```

  ## Flow

  1. User provides source_routine_id (in initial context)
  2. RetrospectiveLens loads and formats the source routine's history
  3. Agent analyzes the history using SequentialThinking (optional)
  4. Agent produces structured knowledge document via StructuredResponse
  5. Document is returned in final context

  ## Output

  The agent returns a `knowledge_document` (markdown string) containing:
  - Quick Reference (TL;DR with 3-5 key takeaways)
  - What was learned (insights not in training data)
  - Prerequisites that would have helped
  - Patterns discovered (what worked, what didn't)
  - Recommendations for similar tasks

  ## Testing

  To test this routine, first complete a task with another routine (like
  ContextAgentRoutine), then run RetrospectiveRoutine with that routine's ID.
  """

  alias Koalemos.Steps.Agent.StructuredResponseAgent

  def start, do: :analyze

  def routine_definition do
    %{
      # Single agent step that does the full analysis
      analyze: %{
        type: StructuredResponseAgent,
        config: %{
          # Template will be evaluated with context
          template: """
          You are analyzing a completed task to extract insights and learnings.

          The conversation history and context from the completed task are provided above
          via the RetrospectiveLens. This is NOT your conversation - you are analyzing it
          as an external observer.

          ## Your Task

          Produce a comprehensive knowledge document that answers these questions:

          ### Quick Reference (TL;DR)
          Start with a brief "Quick Reference" section at the top - a 3-5 bullet point summary
          of the key fixes, solutions, or takeaways. This is for someone who just wants the
          solution without reading the full analysis.

          Example format:
          - Fixed X by doing Y
          - Key insight: Z requires A and B
          - Solution: Change config from X to Y

          ### 1. What Was Learned?
          Identify insights, discoveries, or knowledge that emerged during the task that
          weren't known at the start. Focus on things NOT in your training data - what
          was learned through doing this specific task?

          ### 2. What Prerequisites Would Have Helped?
          What knowledge, context, setup, or preparation would have made this task easier,
          faster, or more effective if it had been available at the start?

          ### 3. What Patterns Emerged?
          What approaches, techniques, workflows, or strategies proved effective?
          What didn't work? What would you do differently?

          ### 4. Key Recommendations
          If someone were starting a similar task fresh, what specific, actionable advice
          would you give them?

          ## Output Format

          Write a clear, well-structured markdown document. Be specific and actionable.
          Use examples from the conversation where relevant. Organize your analysis clearly
          with headers and sections.

          **Important**: Start with the Quick Reference section at the very top of your
          document, before the detailed analysis. This allows readers to quickly find
          the key takeaways without reading the full retrospective.
          """,
          schema: %{
            knowledge_document: %{
              type: :string,
              description: "Complete markdown document with retrospective analysis and insights"
            }
          },
          # Lenses for this step
          lenses: [
            # RetrospectiveLens provides the source routine's history
            ["Koalemos.Lenses.RetrospectiveLens", %{
              source_routine_id: "<%= Map.get(@context, :source_routine_id) %>"
            }],
            # SequentialThinking helps with complex analysis
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:end, :always}]
      }
    }
  end

  def check_condition(:always, _context), do: true

  def initial_context do
    %{
      messages: [
        %{
          role: "user",
          content: "Please analyze the completed task and provide a comprehensive retrospective knowledge document."
        }
      ],
      llm_provider: "anthropic",
      llm_model: "claude-sonnet-4-5",  # Need the smart model for analysis
      max_tokens: 16000,
      temperature: 0.3  # Lower temperature for analytical work
    }
  end
end
