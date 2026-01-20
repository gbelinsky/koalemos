defmodule Koalemos.Routines.RetrospectiveRoutineTest do
  use ExUnit.Case, async: true

  alias Koalemos.Routines.RetrospectiveRoutine
  alias Koalemos.Steps.Agent.StructuredResponseAgent

  describe "routine_definition/0" do
    test "returns valid routine definition with analyze step" do
      definition = RetrospectiveRoutine.routine_definition()

      # Should have analyze step
      assert Map.has_key?(definition, :analyze)

      # Verify step type
      assert definition.analyze.type == StructuredResponseAgent

      # Verify transitions
      assert definition.analyze.transitions == [{:end, :always}]
    end

    test "analyze step has correct configuration" do
      definition = RetrospectiveRoutine.routine_definition()
      config = definition.analyze.config

      # Should have prompt
      assert is_binary(config.prompt)
      assert String.contains?(config.prompt, "analyzing a completed task")
      assert String.contains?(config.prompt, "What Was Learned")

      # Should have schema
      assert is_map(config.schema)
      assert Map.has_key?(config.schema, :knowledge_document)
      assert config.schema.knowledge_document.type == :string

      # Should have lenses configured
      assert is_list(config.lenses)
      
      # Should include RetrospectiveLens with template
      retrospective_lens = Enum.find(config.lenses, fn
        ["Koalemos.Lenses.RetrospectiveLens", _] -> true
        _ -> false
      end)
      assert retrospective_lens != nil
      
      # Should include SequentialThinking
      assert "Koalemos.Lenses.SequentialThinking" in config.lenses
    end
  end

  describe "check_condition/2" do
    test "always returns true for :always condition" do
      assert RetrospectiveRoutine.check_condition(:always, %{}) == true
      assert RetrospectiveRoutine.check_condition(:always, %{foo: "bar"}) == true
    end
  end

  describe "initial_context/0" do
    test "returns default context with required fields" do
      context = RetrospectiveRoutine.initial_context()

      assert context.messages == []
      assert context.llm_provider == "anthropic"
      assert context.llm_model == "claude-sonnet-4-5"
      assert context.max_tokens == 16000
      assert context.temperature == 0.3
    end
  end

  describe "start/0" do
    test "returns :analyze as starting step" do
      assert RetrospectiveRoutine.start() == :analyze
    end
  end
end
