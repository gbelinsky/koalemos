defmodule KoalemosWeb.Routines.BuildWireframeRoutine do
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
      # Stage 1: Planning (no tools, just text response)
      planning: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Based on the user's request, write a brief plan for the wireframe.

          Include:
          - Components needed
          - Basic structure
          - Any interactions required

          Just respond with your plan in plain text.
          """,
          lenses: [
            ["KoalemosWeb.Lenses.WireframeEditor", %{readonly: true}],
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
          Build the HTML structure and layout.

          What the user wants to build (check recent conversation messages)

          Use modify_elements to create the complete HTML structure:
          - Main containers with appropriate IDs
          - Form elements, buttons, inputs (if needed)
          - Structural elements (header, main, footer, sections, etc.)
          - Content elements (headings, paragraphs, labels, placeholders)

          Use manage_css to create the layout (you can call tools in parallel):
          - Layout CSS (flexbox, grid, positioning)
          - Spacing (margins, padding)
          - Container sizing and alignment
          - Basic structural CSS to make the layout work

          Build the full structure with all content and layout CSS.
          Focus on making the layout functional - no visual polish or behavior yet.
          """,
          lenses: [
            "KoalemosWeb.Lenses.WireframeEditor",
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
          Add interactive behavior using handlers and JavaScript.

          What the user wants to build (check recent conversation messages)

          Add interactivity:
          - Event handlers for buttons (onclick, etc.)
          - Form submission handlers
          - Input validation or dynamic behavior
          - Custom JavaScript functions if needed
          - Variables to track state if needed

          Use manage_handlers, manage_functions, and manage_variables.
          Make the wireframe interactive and functional.
          """,
          lenses: [
            "KoalemosWeb.Lenses.WireframeEditor",
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
          Test the wireframe functionality using trigger_interaction.

          TESTING APPROACH - Keep it focused and efficient:
          - Test each interactive element ONCE to verify it works
          - One successful verification per element is sufficient
          - Don't retry or re-test elements that already responded correctly
          - Move on immediately after basic verification

          What to test:
          - Click primary buttons to verify click handlers work
          - If there's a form: fill in ONE field and submit ONCE
          - Test one example of each interaction type (click, submit, etc.)
          - Verify JavaScript handlers execute (check LIVE DOM STATE for changes)

          COMPLETION CRITERIA:
          - Each interactive element tested once → Done
          - Basic functionality verified → Move to polish stage
          - Don't aim for exhaustive testing - one verification per element is enough

          Use trigger_interaction to test (changes are ephemeral).
          Check the LIVE DOM STATE in context to see what happened.
          Document what works, then MOVE ON to polish stage.
          """,
          lenses: [
            "KoalemosWeb.Lenses.WireframeEditor",
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
          Add visual polish and styling to the wireframe.

          What the user wants to build (check recent conversation messages)

          Apply CSS rules using manage_css for visual appeal:
          - Colors and backgrounds (use good contrast ratios)
          - Typography (font sizes 14-16px body, weights, line height 1.5)
          - Borders, shadows, and visual effects
          - Button and form styling (colors, hover states)
          - Visual refinements and professional appearance

          The layout CSS is already done - focus on making it look good.

          IMPORTANT: Apply CSS rules once based on good design principles.
          Do NOT check screenshots to verify - screenshots are not pixel-perfect.
          Trust your CSS choices and move on.
          """,
          lenses: [
            "KoalemosWeb.Lenses.WireframeEditor",
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
        # "KoalemosWeb.Lenses.WireframeEditor",
        "Koalemos.Lenses.SequentialThinking"
      ]
    }
  end

  def setup(_routine_config, _state) do
    {:ok, []}
  end
end
