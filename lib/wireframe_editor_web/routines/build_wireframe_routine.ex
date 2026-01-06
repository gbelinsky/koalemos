defmodule WireframeEditorWeb.Routines.BuildWireframeRoutine do
  @moduledoc """
  V4 multi-stage wireframe building routine with linear sequential flow.

  Clean V4 implementation using StateServer architecture:
  - All stages use WireframeEditor lens
  - StateServer is single source of truth (inherited from parent)
  - No lens_state in context

  ## Build Stages

  Linear sequential flow (no routing decisions):
  1. **planning** - Analyze requirements and plan the wireframe approach
  2. **layout_and_structure** - Build HTML structure + layout CSS
  3. **behavior** - Add event handlers and JavaScript interactivity
  4. **testing** - Test interactions using trigger_interaction tool
  5. **polish** - Add visual styling CSS

  ## Flow

  planning → layout_and_structure → behavior → testing → polish → (returns to parent)
  """

  alias Koalemos.Steps.Agent.TemplatedSemanticAgent

  def start, do: :planning

  def routine_definition do
    %{
      # Stage 1: Planning (readonly - no tools available)
      planning: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          ## PLANNING PHASE (1 of 5)

          You are building a wireframe through 5 sequential phases:
          1. **Planning** (current) - Understand and plan
          2. **Structure** - Build HTML and layout CSS
          3. **Behavior** - Add JavaScript interactivity
          4. **Testing** - Verify everything works
          5. **Polish** - Visual styling and refinement

          No tools are available in this phase. Analyze the user's request and create a plan.

          Your plan should cover:
          - What components are needed (containers, buttons, inputs, etc.)
          - How the layout should be structured
          - What interactions/behaviors are required
          - Any state that needs to be tracked

          Respond with your plan in plain text. Be specific but concise.
          After this, you'll move to the Structure phase where tools become available.
          """,
          lenses: [
            ["WireframeEditorWeb.Lenses.WireframeEditor", %{readonly: true}],
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:layout_and_structure, :always}]
      },

      # Stage 2: Layout & Structure
      layout_and_structure: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          ## STRUCTURE PHASE (2 of 5)

          Now build the HTML structure and layout CSS based on your plan.

          Available tools:
          - **modify_elements**: Add containers, sections, buttons, inputs, text
          - **manage_css**: Set up flexbox/grid layout, spacing, sizing

          Guidelines:
          - Work incrementally - build one section at a time
          - Use placeholder text for content
          - Focus on structure and layout ONLY
          - Do NOT add colors, fancy styling, or JavaScript yet

          When the structure is complete, you'll move to the Behavior phase.
          """,
          lenses: [
            "WireframeEditorWeb.Lenses.WireframeEditor",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:behavior, :always}]
      },

      # Stage 3: Behavior
      behavior: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          ## BEHAVIOR PHASE (3 of 5)

          Now add interactive behavior to make the wireframe functional.

          Available tools:
          - **manage_handlers**: Add click, submit, input event handlers
          - **manage_functions**: Create reusable JavaScript functions
          - **manage_variables**: Set up state variables
          - **manage_init_scripts**: Add initialization code

          Guidelines:
          - Implement the interactions from your plan
          - Keep JavaScript simple and focused
          - Use variables to track state (counters, toggles, etc.)
          - Do NOT add visual styling yet

          When behavior is implemented, you'll move to Testing.
          """,
          lenses: [
            "WireframeEditorWeb.Lenses.WireframeEditor",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:testing, :always}]
      },

      # Stage 4: Testing
      testing: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          ## TESTING PHASE (4 of 5)

          Verify the wireframe works by testing each interactive element.

          Available tools:
          - **trigger_interaction**: Simulate clicks, form submissions, inputs
          - All modification tools (to fix issues you discover)

          Guidelines:
          - Test each button/interaction once
          - Check LIVE DOM STATE after each test to confirm it worked
          - If something fails, fix it and retest
          - Don't over-test - verify core functionality works, then move on

          When core functionality is verified, you'll move to Polish.
          """,
          lenses: [
            "WireframeEditorWeb.Lenses.WireframeEditor",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: [{:polish, :always}]
      },

      # Stage 5: Polish
      polish: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          ## POLISH PHASE (5 of 5)

          Add visual styling to make the wireframe look polished.

          Available tools:
          - **manage_css**: Add colors, typography, borders, shadows, hover states
          - **modify_classes**: Add utility classes if needed

          Guidelines:
          - Apply colors and backgrounds
          - Refine typography (sizes, weights, line-height)
          - Add borders, shadows, rounded corners
          - Add hover/focus states for interactive elements
          - Ensure visual consistency

          This is the final phase. When complete, summarize what you built.
          """,
          lenses: [
            "WireframeEditorWeb.Lenses.WireframeEditor",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: []
      }
    }
  end

  def check_condition(:always, _context), do: true

  def initial_context do
    %{
      messages: [],
      lenses: [
        # "WireframeEditorWeb.Lenses.WireframeEditor",
        "Koalemos.Lenses.SequentialThinking"
      ]
    }
  end

  def setup(_routine_config, _state) do
    {:ok, []}
  end
end
