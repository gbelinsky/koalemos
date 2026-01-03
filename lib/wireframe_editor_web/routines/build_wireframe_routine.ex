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
      # Stage 1: Planning
      planning: %{
        type: TemplatedSemanticAgent,
        config: %{
          template: """
          Plan the wireframe: list components, structure, and interactions needed.
          Respond with your plan in plain text.
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
          Build the HTML structure and layout CSS.

          Use modify_elements for:
          - Containers, sections, headers, footers
          - Form elements, buttons, inputs
          - Content elements with placeholder text

          Use manage_css for layout:
          - Flexbox/grid positioning
          - Spacing and sizing

          Focus on structure and layout only - no behavior or visual polish yet.
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
          Add interactive behavior.

          Use manage_handlers for click/submit/input events.
          Use manage_functions for reusable JavaScript.
          Use manage_variables for state tracking.

          Make the wireframe functional.
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
          Verify the wireframe works using trigger_interaction.

          Test each interactive element once:
          - Click buttons to verify handlers fire
          - Fill and submit forms if present
          - Check LIVE DOM STATE to confirm changes

          If something doesn't work, fix it with the appropriate tool, then retest.
          When core functionality works, move on.
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
          Add visual styling with manage_css.

          Apply:
          - Colors and backgrounds
          - Typography (sizes, weights)
          - Borders, shadows, hover states

          Layout is done - focus on visual appeal.
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
