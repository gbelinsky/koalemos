defmodule Koalemos.Routines.PersonaTestRoutineTest do
  use ExUnit.Case, async: true

  alias Koalemos.Routines.PersonaTestRoutine

  describe "routine_definition/0" do
    test "returns valid routine definition with all steps" do
      definition = PersonaTestRoutine.routine_definition()

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
      definition = PersonaTestRoutine.routine_definition()

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
      assert PersonaTestRoutine.check_condition(:always, %{}) == true
      assert PersonaTestRoutine.check_condition(:always, %{foo: "bar"}) == true
    end
  end

  describe "initial_context/0" do
    test "returns default context with required fields" do
      context = PersonaTestRoutine.initial_context()

      assert context.messages == []
      assert context.llm_provider == "anthropic"
      assert context.llm_model == "claude-haiku-4-5"
      assert context.max_tokens == 2000
      assert context.temperature == 0.7
    end

    test "includes PersonaLens with default professional/technical/balanced config" do
      context = PersonaTestRoutine.initial_context()

      assert length(context.lenses) == 1

      # Should have PersonaLens with config
      [["Koalemos.Lenses.PersonaLens", persona_config]] = context.lenses

      assert persona_config.tone == :professional
      assert persona_config.expertise == [:technical]
      assert persona_config.style == :balanced
    end

    test "default persona config uses correct dimensional values" do
      context = PersonaTestRoutine.initial_context()

      [["Koalemos.Lenses.PersonaLens", persona_config]] = context.lenses

      # Tone is single value
      assert is_atom(persona_config.tone)
      assert persona_config.tone in [:professional, :casual, :friendly, :empathetic]

      # Expertise is list
      assert is_list(persona_config.expertise)

      Enum.each(persona_config.expertise, fn expertise ->
        assert expertise in [:technical, :creative, :business, :analytical, :ux]
      end)

      # Style is single value
      assert is_atom(persona_config.style)
      assert persona_config.style in [:concise, :detailed, :balanced, :storytelling]
    end

    test "user context can override persona config" do
      defaults = PersonaTestRoutine.initial_context()

      # User provides different persona config
      user_context = %{
        lenses: [
          [
            "Koalemos.Lenses.PersonaLens",
            %{
              tone: :friendly,
              expertise: [:creative, :ux],
              style: :storytelling
            }
          ]
        ]
      }

      merged = Map.merge(defaults, user_context)

      # User's persona config overrides default
      [["Koalemos.Lenses.PersonaLens", persona_config]] = merged.lenses

      assert persona_config.tone == :friendly
      assert persona_config.expertise == [:creative, :ux]
      assert persona_config.style == :storytelling
    end

    test "user context can override LLM settings" do
      defaults = PersonaTestRoutine.initial_context()

      user_context = %{
        temperature: 0.9,
        max_tokens: 4000
      }

      merged = Map.merge(defaults, user_context)

      # User values override defaults
      assert merged.temperature == 0.9
      assert merged.max_tokens == 4000

      # Defaults remain for non-overridden fields
      assert merged.llm_provider == "anthropic"
      assert merged.llm_model == "claude-haiku-4-5"
    end

    test "user can add custom fields" do
      defaults = PersonaTestRoutine.initial_context()

      user_context = %{
        custom_field: "custom_value",
        session_id: "test-123"
      }

      merged = Map.merge(defaults, user_context)

      # Custom fields are included
      assert merged.custom_field == "custom_value"
      assert merged.session_id == "test-123"

      # Defaults still present
      assert merged.messages == []
      assert merged.llm_provider == "anthropic"
    end
  end
end
