defmodule Koalemos.Routines.WireframeTestRoutineTest do
  use ExUnit.Case, async: true

  alias Koalemos.Routines.WireframeTestRoutine

  @fixtures_path "test/fixtures"

  describe "routine_definition/0" do
    test "returns valid routine definition with all steps" do
      definition = WireframeTestRoutine.routine_definition()

      # Should have all four steps
      assert Map.has_key?(definition, :start)
      assert Map.has_key?(definition, :render_lens)
      assert Map.has_key?(definition, :llm_request)
      assert Map.has_key?(definition, :parse_response)

      # Verify step types
      assert definition.start.type == Koalemos.Steps.User.ChatUserInput
      assert definition.render_lens.type == Koalemos.Steps.Agent.LensRendering
      assert definition.llm_request.type == Koalemos.Steps.Agent.LLMRequest
      assert definition.parse_response.type == Koalemos.Steps.Agent.ResponseParsing
    end

    test "has correct transition flow with tool execution support" do
      definition = WireframeTestRoutine.routine_definition()

      # start -> build_tool_schema (Sprint 4: tool execution added)
      assert definition.start.transitions == [{:build_tool_schema, :always}]

      # build_tool_schema -> render_lens
      assert definition.build_tool_schema.transitions == [{:render_lens, :always}]

      # render_lens -> llm_request
      assert definition.render_lens.transitions == [{:llm_request, :always}]

      # llm_request -> parse_response
      assert definition.llm_request.transitions == [{:parse_response, :always}]

      # parse_response -> tool_lookup (if tools) OR start (if no tools)
      assert definition.parse_response.transitions == [
        {:tool_lookup, :when_has_tool_calls},
        {:start, :when_no_tool_calls}
      ]

      # tool_lookup -> tool_execution
      assert definition.tool_lookup.transitions == [{:tool_execution, :always}]

      # tool_execution -> tool_execution (more tools) OR build_tool_schema (complete)
      assert definition.tool_execution.transitions == [
        {:tool_execution, :when_has_more_tools},
        {:build_tool_schema, :when_tools_complete}
      ]
    end
  end

  describe "check_condition/2" do
    test "always returns true for :always condition" do
      assert WireframeTestRoutine.check_condition(:always, %{}) == true
      assert WireframeTestRoutine.check_condition(:always, %{foo: "bar"}) == true
    end
  end

  describe "initial_context/0" do
    test "returns default context with required fields" do
      context = WireframeTestRoutine.initial_context()

      assert context.messages == []
      # Sprint 4: WireframeEditor lens now included by default
      assert context.lenses == ["Koalemos.Lenses.WireframeEditor"]
      assert context.llm_provider == "anthropic"
      assert context.llm_model == "claude-haiku-4-5"
      assert context.max_tokens == 64000  # Higher token limit for wireframe context
      assert context.temperature == 0.7
      assert context.wireframe_html == nil
      assert context.wireframe_sample == nil
    end
  end

  describe "setup/2" do
    test "loads simple wireframe when wireframe_sample is in context" do
      state = %{
        context: %{
          wireframe_sample: "simple",
          wireframe_html: nil
        }
      }

      {:ok, diff} = WireframeTestRoutine.setup(%{}, state)
      {:ok, updated_context} = Koalemos.Engine.ContextManager.apply_diff(state.context, diff)
      updated_state = %{state | context: updated_context}

      assert is_binary(updated_state.context.wireframe_html)
      assert updated_state.context.wireframe_html =~ "<!DOCTYPE html>"
      assert updated_state.context.wireframe_html =~ "Simple Wireframe"
    end

    test "loads medium wireframe when wireframe_sample is in context" do
      state = %{
        context: %{
          wireframe_sample: "medium",
          wireframe_html: nil
        }
      }

      {:ok, diff} = WireframeTestRoutine.setup(%{}, state)
      {:ok, updated_context} = Koalemos.Engine.ContextManager.apply_diff(state.context, diff)
      updated_state = %{state | context: updated_context}

      assert is_binary(updated_state.context.wireframe_html)
      assert updated_state.context.wireframe_html =~ "<!DOCTYPE html>"
      assert updated_state.context.wireframe_html =~ "Medium"
      assert updated_state.context.wireframe_html =~ "<style>"
    end

    test "loads complex wireframe when wireframe_sample is in context" do
      state = %{
        context: %{
          wireframe_sample: "complex",
          wireframe_html: nil
        }
      }

      {:ok, diff} = WireframeTestRoutine.setup(%{}, state)
      {:ok, updated_context} = Koalemos.Engine.ContextManager.apply_diff(state.context, diff)
      updated_state = %{state | context: updated_context}

      assert is_binary(updated_state.context.wireframe_html)
      assert updated_state.context.wireframe_html =~ "<!DOCTYPE html>"
      assert updated_state.context.wireframe_html =~ "Complex"
      assert updated_state.context.wireframe_html =~ "<style>"
      assert updated_state.context.wireframe_html =~ "<script>"
      assert updated_state.context.wireframe_html =~ "addEventListener"
    end

    test "handles invalid sample gracefully" do
      state = %{
        context: %{
          wireframe_sample: "nonexistent",
          wireframe_html: nil
        }
      }

      {:ok, diff} = WireframeTestRoutine.setup(%{}, state)
      {:ok, updated_context} = Koalemos.Engine.ContextManager.apply_diff(state.context, diff)
      updated_state = %{state | context: updated_context}

      # Should not crash, just leave wireframe_html as nil
      assert updated_state.context.wireframe_html == nil
      assert updated_state.context.wireframe_sample == "nonexistent"
    end

    test "preserves existing wireframe_html when no sample specified" do
      custom_html = "<html><body>Custom wireframe</body></html>"
      state = %{
        context: %{
          wireframe_html: custom_html
        }
      }

      {:ok, diff} = WireframeTestRoutine.setup(%{}, state)
      {:ok, updated_context} = Koalemos.Engine.ContextManager.apply_diff(state.context, diff)
      updated_state = %{state | context: updated_context}

      assert updated_state.context.wireframe_html == custom_html
    end

    test "wireframe_sample overrides existing wireframe_html" do
      custom_html = "<html><body>Custom wireframe</body></html>"

      state = %{
        context: %{
          wireframe_html: custom_html,
          wireframe_sample: "simple"
        }
      }

      {:ok, diff} = WireframeTestRoutine.setup(%{}, state)
      {:ok, updated_context} = Koalemos.Engine.ContextManager.apply_diff(state.context, diff)
      updated_state = %{state | context: updated_context}

      # Sample should load and override the existing wireframe_html
      assert updated_state.context.wireframe_html =~ "Simple Wireframe"
      refute updated_state.context.wireframe_html == custom_html
    end
  end

  describe "sample files validation" do
    test "all sample files exist" do
      assert File.exists?(Path.join([@fixtures_path, "wireframe_simple.html"]))
      assert File.exists?(Path.join([@fixtures_path, "wireframe_medium.html"]))
      assert File.exists?(Path.join([@fixtures_path, "wireframe_complex.html"]))
    end

    test "all sample files contain valid HTML" do
      for sample <- ["simple", "medium", "complex"] do
        state = %{context: %{wireframe_sample: sample, wireframe_html: nil}}
        {:ok, diff} = WireframeTestRoutine.setup(%{}, state)
      {:ok, updated_context} = Koalemos.Engine.ContextManager.apply_diff(state.context, diff)
      updated_state = %{state | context: updated_context}

        assert updated_state.context.wireframe_html =~ "<!DOCTYPE html>"
        assert updated_state.context.wireframe_html =~ "<html"
        assert updated_state.context.wireframe_html =~ "</html>"
        assert updated_state.context.wireframe_html =~ "<body"
        assert updated_state.context.wireframe_html =~ "</body>"
      end
    end
  end

  describe "routine characteristics" do
    test "extends TestChatRoutine pattern with tool execution support" do
      wireframe_def = WireframeTestRoutine.routine_definition()
      test_chat_def = Koalemos.Routines.TestChatRoutine.routine_definition()

      # Should have all TestChatRoutine steps plus tool execution steps
      test_chat_steps = MapSet.new(Map.keys(test_chat_def))
      wireframe_steps = MapSet.new(Map.keys(wireframe_def))

      # All test_chat steps should be present in wireframe
      assert MapSet.subset?(test_chat_steps, wireframe_steps)

      # Wireframe should have additional tool execution steps
      assert Map.has_key?(wireframe_def, :tool_lookup)
      assert Map.has_key?(wireframe_def, :tool_execution)

      # Should have same step types for shared steps
      assert wireframe_def.start.type == test_chat_def.start.type
      assert wireframe_def.render_lens.type == test_chat_def.render_lens.type
      assert wireframe_def.llm_request.type == test_chat_def.llm_request.type
      assert wireframe_def.parse_response.type == test_chat_def.parse_response.type
    end

    test "includes WireframeEditor lens by default (Sprint 4 complete)" do
      context = WireframeTestRoutine.initial_context()
      assert context.lenses == ["Koalemos.Lenses.WireframeEditor"]
    end

    test "supports lens overrides through context merging" do
      # Engine merges user context with defaults
      # Users can override the default lens if needed
      defaults = WireframeTestRoutine.initial_context()
      user_overrides = %{lenses: ["CustomLens"]}
      merged = Map.merge(defaults, user_overrides)

      assert merged.lenses == ["CustomLens"]
    end
  end
end
