defmodule Koalemos.Routines.BuildWireframeRoutineTest do
  use ExUnit.Case, async: true
  alias Koalemos.Routines.BuildWireframeRoutine

  describe "start/0" do
    test "returns planning as the starting step" do
      assert BuildWireframeRoutine.start() == :planning
    end
  end

  describe "routine_definition/0" do
    test "returns valid routine structure" do
      definition = BuildWireframeRoutine.routine_definition()

      assert is_map(definition)
      assert map_size(definition) == 5
    end

    test "has all expected stages in sequential order" do
      definition = BuildWireframeRoutine.routine_definition()

      # All stages should exist
      assert Map.has_key?(definition, :planning)
      assert Map.has_key?(definition, :layout_and_structure)
      assert Map.has_key?(definition, :behavior)
      assert Map.has_key?(definition, :testing)
      assert Map.has_key?(definition, :polish)
    end

    test "follows linear sequential flow" do
      definition = BuildWireframeRoutine.routine_definition()

      # Verify the sequential transitions
      assert definition.planning.transitions == [{:layout_and_structure, :always}]
      assert definition.layout_and_structure.transitions == [{:behavior, :always}]
      assert definition.behavior.transitions == [{:testing, :always}]
      assert definition.testing.transitions == [{:polish, :always}]
      assert definition.polish.transitions == []
    end

    test "all stages use TemplatedSemanticAgent" do
      definition = BuildWireframeRoutine.routine_definition()

      assert definition.planning.type == Koalemos.Steps.Agent.TemplatedSemanticAgent
      assert definition.layout_and_structure.type == Koalemos.Steps.Agent.TemplatedSemanticAgent
      assert definition.behavior.type == Koalemos.Steps.Agent.TemplatedSemanticAgent
      assert definition.testing.type == Koalemos.Steps.Agent.TemplatedSemanticAgent
      assert definition.polish.type == Koalemos.Steps.Agent.TemplatedSemanticAgent
    end

    test "planning stage is readonly" do
      definition = BuildWireframeRoutine.routine_definition()

      # Planning should have readonly WireframeEditorV4 lens
      planning_lenses = definition.planning.config.lenses
      assert Enum.any?(planning_lenses, fn
               ["Koalemos.Lenses.WireframeEditorV4", %{readonly: true}] -> true
               _ -> false
             end)
    end

    test "layout_and_structure stage instructs both HTML and CSS" do
      definition = BuildWireframeRoutine.routine_definition()

      template = definition.layout_and_structure.config.template

      # Should mention both element modification and CSS
      assert template =~ "modify_elements"
      assert template =~ "manage_css"
      assert template =~ "layout"
    end

    test "polish stage warns about screenshot verification" do
      definition = BuildWireframeRoutine.routine_definition()

      template = definition.polish.config.template

      # Should have the important warning about not checking screenshots
      assert template =~ "Do NOT check screenshots"
      assert template =~ "pixel-perfect"
      assert template =~ "Trust your CSS"
    end
  end

  describe "initial_context/0" do
    test "returns map with required fields" do
      context = BuildWireframeRoutine.initial_context()

      assert Map.has_key?(context, :messages)
      assert Map.has_key?(context, :lenses)
    end

    test "has default lenses" do
      context = BuildWireframeRoutine.initial_context()

      assert "Koalemos.Lenses.WireframeEditorV4" in context.lenses
      assert "Koalemos.Lenses.SequentialThinking" in context.lenses
    end
  end

  describe "setup/2" do
    test "returns ok tuple with empty changes" do
      state = %{context: BuildWireframeRoutine.initial_context()}
      assert {:ok, []} = BuildWireframeRoutine.setup(%{}, state)
    end
  end

  describe "check_condition/2" do
    test "always condition returns true" do
      assert BuildWireframeRoutine.check_condition(:always, %{}) == true
    end
  end
end
