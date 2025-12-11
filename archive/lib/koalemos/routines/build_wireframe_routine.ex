defmodule Koalemos.Routines.BuildWireframeRoutine do
  @moduledoc """
  Multi-stage wireframe building routine with linear sequential flow.

  This routine demonstrates a scripted playbook by breaking down the "build from scratch"
  task into multiple coordinated stages executed in sequence.

  ## Architecture Pattern

  **Linear Sequential Flow:**
  planning → layout_and_structure → behavior → testing → polish

  Each stage has a specific responsibility and executes in a predetermined order.
  No routing decisions - this is a known sequence for building wireframes.
  The parent routine (WireframeDesignRoutine) handles result summarization.

  ## Build Stages

  - **planning** - Analyze requirements and plan the wireframe approach
  - **layout_and_structure** - Build HTML structure + layout CSS (flexbox/grid/spacing)
  - **behavior** - Add event handlers and JavaScript interactivity
  - **testing** - Test interactions using trigger_interaction tool
  - **polish** - Add visual styling CSS (colors, typography, effects)

  ## Linear Playbook

  This is a scripted sequence - no routing decisions needed:
  - We know the steps required to build a wireframe
  - Each stage has a clear, specific responsibility
  - Agent executes each stage in order
  - Testing is guaranteed to happen (not agent-decided)

  ## Example Flow

  ```
  User: "Build a login form"
    ↓
  planning → analyze requirements, plan structure
    ↓
  layout_and_structure → create HTML + layout CSS (flexbox, spacing, containers)
    ↓
  behavior → add click handlers, form validation
    ↓
  testing → test button clicks, form submission
    ↓
  polish → add visual CSS (colors, typography, shadows)
    ↓
  (returns to parent routine's show_result step)
  ```

  ## Initial Context

  Inherits context from parent routine (WireframeDesignRoutine):
  - `wireframe_html` - Current wireframe HTML
  - `lens_state` - Current DOM tree and state
  - `messages` - Conversation history with user's request
  """

  alias Koalemos.Steps.Agent.TemplatedSemanticAgent

  def start, do: :planning

  @doc """
  Returns the routine definition as a linear build sequence.

  Sequential flow:
  planning → layout_and_structure → behavior → testing → polish
  """
  def routine_definition do
    %{

      # Stage 1: Planning
      planning: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Analyze what the user wants and plan the wireframe.

          Review the recent conversation to understand what the user asked for.

          Use sequential_thinking to:
          1. Break down what components are needed (e.g., header, form, buttons, etc.)
          2. Plan the HTML structure and hierarchy
          3. Consider what interactions and behaviors will be needed
          4. Think about layout and styling approach

          Document your plan clearly for the next stages.
          """,
          lenses: [
            ["Koalemos.Lenses.WireframeEditorV4", %{readonly: true}],
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
            "Koalemos.Lenses.WireframeEditorV4",
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
            "Koalemos.Lenses.WireframeEditorV4",
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
            "Koalemos.Lenses.WireframeEditorV4",
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
            "Koalemos.Lenses.WireframeEditorV4",
            "Koalemos.Lenses.SequentialThinking"
          ]
        },
        transitions: []
      }
    }
  end

  @doc """
  Condition check function - always returns true.
  All semantic routing is handled by SemanticTransition lens.
  """
  def check_condition(:always, _context), do: true

  @doc """
  Returns default initial context.
  Typically called as a sub-routine, so inherits parent context.
  """
  def initial_context do
    %{
      messages: [],
      lenses: [
        "Koalemos.Lenses.WireframeEditorV4",
        "Koalemos.Lenses.SequentialThinking"
      ]
    }
  end

  @doc """
  Setup function - no special setup needed for build routine.
  Inherits lens_state from parent routine.
  """
  def setup(_routine_config, _state) do
    {:ok, []}
  end
end
