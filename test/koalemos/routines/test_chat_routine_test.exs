defmodule Koalemos.Routines.TestChatRoutineTest do
  use ExUnit.Case, async: true

  alias Koalemos.Routines.TestChatRoutine

  describe "routine_definition/0" do
    test "returns valid routine definition with all steps" do
      definition = TestChatRoutine.routine_definition()

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

    test "has correct transition flow: start -> lens -> llm -> parse -> start (loops)" do
      definition = TestChatRoutine.routine_definition()

      # start -> render_lens
      assert definition.start.transitions == [{:render_lens, :always}]

      # render_lens -> llm_request
      assert definition.render_lens.transitions == [{:llm_request, :always}]

      # llm_request -> parse_response
      assert definition.llm_request.transitions == [{:parse_response, :always}]

      # parse_response -> start (loops back)
      assert definition.parse_response.transitions == [{:start, :always}]
    end
  end

  describe "check_condition/2" do
    test "always returns true for :always condition" do
      assert TestChatRoutine.check_condition(:always, %{}) == true
      assert TestChatRoutine.check_condition(:always, %{foo: "bar"}) == true
    end
  end

  describe "initial_context/1" do
    test "returns default context with required fields" do
      context = TestChatRoutine.initial_context()

      assert context.messages == []
      assert context.active_lenses == ["Koalemos.Lenses.TestLens"]
      assert context.llm_provider == "anthropic"
      assert context.llm_model == "claude-haiku-4-5"
      assert context.max_tokens == 2000
      assert context.temperature == 0.7
    end

    test "merges user context with defaults" do
      user_context = %{
        messages: [%{role: "user", content: "test"}],
        temperature: 0.9,
        custom_field: "custom_value"
      }

      context = TestChatRoutine.initial_context(user_context)

      # User values override defaults
      assert context.messages == [%{role: "user", content: "test"}]
      assert context.temperature == 0.9

      # Custom fields are included
      assert context.custom_field == "custom_value"

      # Defaults are still present for non-overridden fields
      assert context.active_lenses == ["Koalemos.Lenses.TestLens"]
      assert context.llm_provider == "anthropic"
      assert context.llm_model == "claude-haiku-4-5"
      assert context.max_tokens == 2000
    end
  end
end
