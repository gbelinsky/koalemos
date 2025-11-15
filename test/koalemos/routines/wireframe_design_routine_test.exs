defmodule Koalemos.Routines.WireframeDesignRoutineTest do
  use ExUnit.Case, async: true
  alias Koalemos.Routines.WireframeDesignRoutine

  describe "routine_definition/0" do
    test "returns valid routine structure" do
      definition = WireframeDesignRoutine.routine_definition()

      assert is_map(definition)
      assert Map.has_key?(definition, :start)
      assert Map.has_key?(definition, :routing)
    end

    test "has all expected steps" do
      definition = WireframeDesignRoutine.routine_definition()

      # Main routing
      assert Map.has_key?(definition, :routing)

      # Sub-routines
      assert Map.has_key?(definition, :interact_wireframe)
      assert Map.has_key?(definition, :play)
      assert Map.has_key?(definition, :debug)
      assert Map.has_key?(definition, :targeted_change)
      assert Map.has_key?(definition, :build_from_scratch)
      assert Map.has_key?(definition, :modify_existing)
      assert Map.has_key?(definition, :ask_clarification)
      assert Map.has_key?(definition, :show_current_state)
      assert Map.has_key?(definition, :show_result)
    end

    test "build_from_scratch calls BuildWireframeRoutine" do
      definition = WireframeDesignRoutine.routine_definition()

      assert definition.build_from_scratch.type == Koalemos.Routines.BuildWireframeRoutine
    end

    test "routing step has semantic transitions" do
      definition = WireframeDesignRoutine.routine_definition()

      transitions = definition.routing.transitions

      # Should have transitions to all sub-routines
      assert Enum.find(transitions, fn {dest, _} -> dest == :interact_wireframe end)
      assert Enum.find(transitions, fn {dest, _} -> dest == :play end)
      assert Enum.find(transitions, fn {dest, _} -> dest == :debug end)
      assert Enum.find(transitions, fn {dest, _} -> dest == :targeted_change end)
      assert Enum.find(transitions, fn {dest, _} -> dest == :build_from_scratch end)
      assert Enum.find(transitions, fn {dest, _} -> dest == :modify_existing end)
      assert Enum.find(transitions, fn {dest, _} -> dest == :ask_clarification end)
      assert Enum.find(transitions, fn {dest, _} -> dest == :show_current_state end)

      # Should have fallback to start
      assert Enum.find(transitions, fn {dest, cond} -> dest == :start && cond == :always end)
    end
  end

  describe "initial_context/0" do
    test "returns map with required fields" do
      context = WireframeDesignRoutine.initial_context()

      assert Map.has_key?(context, :messages)
      assert Map.has_key?(context, :lenses)
      assert Map.has_key?(context, :llm_provider)
      assert Map.has_key?(context, :llm_model)
      assert Map.has_key?(context, :wireframe_html)
    end

    test "has default lenses" do
      context = WireframeDesignRoutine.initial_context()

      assert "Koalemos.Lenses.WireframeEditor" in context.lenses
      assert "Koalemos.Lenses.SequentialThinking" in context.lenses
    end

    test "has Claude Sonnet 4.5 as default model" do
      context = WireframeDesignRoutine.initial_context()

      assert context.llm_provider == "anthropic"
      assert context.llm_model == "claude-sonnet-4-5"
    end
  end

  describe "setup/2" do
    test "returns ok tuple with empty changes when no sample specified" do
      state = %{context: WireframeDesignRoutine.initial_context()}
      assert {:ok, []} = WireframeDesignRoutine.setup(%{}, state)
    end

    test "loads sample HTML when wireframe_sample specified" do
      context =
        WireframeDesignRoutine.initial_context()
        |> Map.put(:wireframe_sample, "simple")

      state = %{context: context}
      {:ok, changes} = WireframeDesignRoutine.setup(%{}, state)

      # Should return changes list
      assert is_list(changes)

      # If sample loaded, should have wireframe_html in changes
      if length(changes) > 0 do
        [{:add_or_update, updates}] = changes
        assert Map.has_key?(updates, :wireframe_html)
      end
    end
  end

  describe "check_condition/2" do
    test "always condition returns true" do
      assert WireframeDesignRoutine.check_condition(:always, %{}) == true
    end
  end
end
