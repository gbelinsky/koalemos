defmodule Koalemos.Routines.KnowledgeExtractionRoutine do
  @moduledoc """
  Extracts structured, atomic insights from a retrospective knowledge document.

  Takes a completed retrospective's knowledge_document (markdown) and breaks it
  down into discrete, actionable insights that can be stored and retrieved
  efficiently.

  ## Purpose

  Transform verbose retrospectives into atomic knowledge units:
  - Each insight is self-contained and understandable alone
  - Tagged with domain for efficient retrieval
  - Summarized for quick context injection
  - Linked back to source retrospective for full details

  ## Usage

  ```elixir
  # After RetrospectiveRoutine completes, get the knowledge document
  {:ok, retro_info} = EngineManager.get_routine(retrospective_id)
  knowledge_doc = get_in(retro_info.context, [:structured_output, "knowledge_document"])

  # Start extraction routine with document in initial message
  {:ok, extraction_id} = Koalemos.EngineManager.start_routine(
    "extract-#{System.unique_integer([:positive])}",
    Koalemos.Routines.KnowledgeExtractionRoutine,
    %{
      source_retrospective_id: retrospective_id,
      messages: [
        %{
          role: "user",
          content: \"""
          Please extract discrete, actionable insights from the following retrospective analysis.

          # Retrospective Document

          \#{knowledge_doc}

          Extract insights following the guidelines provided in your system prompt.
          \"""
        }
      ]
    }
  )
  ```

  ## Flow

  1. User provides knowledge_document (from RetrospectiveRoutine output)
  2. Agent reads and analyzes the document
  3. Agent extracts discrete insights using StructuredResponseAgent
  4. Each insight is validated and structured with schema
  5. Caller can then augment with timestamps/IDs and store in Mnesia

  ## Output

  Returns `insights` - a list of structured insight objects:

  ```elixir
  [
    %{
      domain: "css/tailwind",
      summary: "Tailwind prose-slate variant is hard to override",
      reminder: "When using prose, avoid prose-slate. Use explicit colors instead.",
      applies_when: "CSS rendering issues with Tailwind typography plugin",
      section: "What Was Learned"
    },
    %{
      domain: "testing/workflow",
      summary: "First fix wasn't tested before declaring success",
      reminder: "Always test CSS changes in browser before reporting completion",
      applies_when: "Making styling or UI changes",
      section: "What Didn't Work"
    },
    ...
  ]
  ```

  ## Integration with Mnesia

  After extraction, augment and store:

  ```elixir
  {:ok, info} = EngineManager.get_routine(extraction_id)
  insights = info.context[:structured_output]["insights"]

  # Augment with metadata
  enriched_insights = Enum.map(insights, fn insight ->
    %{
      id: generate_id(),
      timestamp: DateTime.utc_now(),
      source_retrospective_id: source_retro_id,
      source_routine_id: original_routine_id,
      # ... original insight fields
    }
    |> Map.merge(insight)
  end)

  # Store in Mnesia
  KnowledgeBase.store_insights(enriched_insights)
  ```
  """

  alias Koalemos.Steps.Agent.StructuredResponseAgent

  def start, do: :extract

  def routine_definition do
    %{
      # Single step that extracts insights
      extract: %{
        type: StructuredResponseAgent,
        config: %{
          template: """
          You are extracting discrete, actionable insights from a retrospective analysis.

          The retrospective document is provided in your initial message. Your task is to
          read it carefully and extract atomic knowledge units that can be stored and
          retrieved independently.

          ## Extraction Guidelines

          ### What Makes a Good Insight?

          Each insight should be:

          1. **Self-contained**: Understandable without reading the full retrospective
          2. **Actionable**: Clear about what to do or what to avoid
          3. **Specific**: Not too general ("use good practices") but not too narrow
          4. **Domain-specific**: Clearly tagged so it can be retrieved when relevant

          ### Domains to Consider

          Tag each insight with the most specific applicable domain:

          - `css` - CSS styling, selectors, specificity
          - `css/tailwind` - Tailwind-specific patterns
          - `testing` - Testing strategies, verification
          - `testing/integration` - Integration testing specifics
          - `debugging` - Debugging techniques, troubleshooting
          - `debugging/browser` - Browser-specific debugging
          - `architecture` - System design, structure
          - `workflow` - Development process, iteration
          - `project-specific` - Specific to this codebase
          - `general` - Broadly applicable learnings

          You can create new domains if needed - be specific but not overly granular.

          ### What to Extract

          Focus on:

          ✓ Technical insights (how something works, why it failed)
          ✓ Patterns that worked or didn't work
          ✓ Prerequisites that would have helped
          ✓ Mistakes to avoid
          ✓ Configuration or API gotchas
          ✓ Testing or verification lessons

          Skip:

          ✗ Step-by-step logs of what was done
          ✗ Generic advice that's not tied to specific learning
          ✗ Background information without actionable takeaway

          ### Fields to Populate

          - **domain**: The most specific applicable domain (e.g., "css/tailwind")
          - **summary**: A clear one-sentence summary of the insight (1-2 lines)
          - **reminder**: A concise, actionable reminder for future situations (1-2 lines)
          - **applies_when**: Description of when this insight is relevant (1-2 lines)
          - **section**: Which section of the retrospective this came from

          ### Example Quality Bar

          Good:
          ```
          domain: "css/tailwind"
          summary: "Tailwind's prose-slate variant sets default colors that are hard to override with modifier classes"
          reminder: "When using prose plugin, avoid color variants (prose-slate, prose-gray). Use explicit color classes instead (prose-code:text-slate-800)"
          applies_when: "Styling markdown content with Tailwind typography plugin"
          section: "What Was Learned"
          ```

          Too vague:
          ```
          domain: "css"
          summary: "CSS is tricky"
          reminder: "Be careful with CSS"
          ```

          Too specific (too tied to one instance):
          ```
          domain: "css/tailwind"
          summary: "Line 1283 in inspector_live.ex had prose-slate which caused white text"
          reminder: "Don't use prose-slate on line 1283"
          ```

          ## Your Task

          Extract all valuable insights from the retrospective document. Aim for 5-15 insights
          depending on the retrospective's depth. Each should be a discrete, reusable piece
          of knowledge.
          """,
          schema: %{
            insights: %{
              type: :array,
              description: "List of discrete, actionable insights extracted from the retrospective",
              items: %{
                domain: %{
                  type: :string,
                  description: "Most specific applicable domain (e.g., 'css/tailwind', 'testing/integration')"
                },
                summary: %{
                  type: :string,
                  description: "One-sentence summary of the insight (1-2 lines)"
                },
                reminder: %{
                  type: :string,
                  description: "Concise, actionable reminder for future situations (1-2 lines)"
                },
                applies_when: %{
                  type: :string,
                  description: "Description of when this insight is relevant (1-2 lines)"
                },
                section: %{
                  type: :string,
                  description: "Which section of the retrospective this came from"
                }
              }
            }
          },
          # No lenses needed - the document is in the initial message
          lenses: []
        },
        transitions: [{:end, :always}]
      }
    }
  end

  def check_condition(:always, _context), do: true

  def initial_context do
    %{
      # Caller provides messages with knowledge_document interpolated
      # See usage example above
      messages: [],
      llm_provider: "anthropic",
      llm_model: "claude-sonnet-4-5",  # Need smart model for extraction
      max_tokens: 8000,
      temperature: 0.3  # Lower temperature for structured extraction
    }
  end
end
