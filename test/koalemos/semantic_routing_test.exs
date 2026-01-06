defmodule Koalemos.SemanticRoutingTest do
  use ExUnit.Case, async: false

  alias Koalemos.Steps.Agent.TemplatedSemanticAgent
  alias Koalemos.Lenses.SemanticTransition

  describe "TemplatedSemanticAgent" do
    test "has routine_definition/0 with complete agent loop" do
      # Call the function directly to verify it exists and returns correct structure
      definition = TemplatedSemanticAgent.routine_definition()

      # Should have all 6 agent loop steps
      assert is_map(definition)
      assert Map.has_key?(definition, :start)
      assert Map.has_key?(definition, :render_lens)
      assert Map.has_key?(definition, :llm_request)
      assert Map.has_key?(definition, :parse_response)
      assert Map.has_key?(definition, :tool_lookup)
      assert Map.has_key?(definition, :tool_execution)

      # Verify step structure matches complete loop
      assert definition.start.type == Koalemos.Steps.Agent.ToolSchema
      assert definition.render_lens.type == Koalemos.Steps.Agent.LensRendering
      assert definition.llm_request.type == Koalemos.Steps.Agent.LLMRequest
      assert definition.parse_response.type == Koalemos.Steps.Agent.ResponseParsing
      assert definition.tool_lookup.type == Koalemos.Steps.Agent.ToolLookup
      assert definition.tool_execution.type == Koalemos.Steps.Agent.ToolExecution
    end

    test "setup renders template with context access" do
      template = "User request: <%= @context[:user_message] %>"

      config_sources = %{
        static: %{template: template, lenses: []},
        runtime: %{}
      }

      state = %{
        context: %{
          user_message: "Hello world",
          messages: []
        }
      }

      {:ok, diff} = TemplatedSemanticAgent.setup(config_sources, state)

      # Should save base lenses and set step_system_prompt (not user message)
      assert Enum.any?(diff, fn
               {:add_or_update, %{_routine_base_lenses: _}} -> true
               _ -> false
             end)

      assert Enum.any?(diff, fn
               {:add_or_update, %{step_system_prompt: prompt}} ->
                 prompt == "User request: Hello world"

               _ ->
                 false
             end)
    end

    test "setup without template but with lenses merges with inherited lenses" do
      config_sources = %{
        static: %{lenses: ["TestLens"]},
        runtime: %{}
      }

      state = %{context: %{lenses: ["ExistingLens"]}}

      {:ok, diff} = TemplatedSemanticAgent.setup(config_sources, state)

      # Should save base lenses and merge config lenses with them
      # Extract the lenses update from diff
      lenses_update =
        Enum.find_value(diff, fn
          {:add_or_update, %{lenses: lenses}} -> lenses
          _ -> nil
        end)

      assert lenses_update != nil
      assert ["ExistingLens", %{}] in lenses_update
      assert ["TestLens", %{}] in lenses_update
    end

    test "setup with config lens that overrides inherited lens" do
      config_sources = %{
        static: %{lenses: [["SameLens", %{config: "override"}]]},
        runtime: %{}
      }

      state = %{context: %{lenses: ["SameLens", "OtherLens"]}}

      {:ok, diff} = TemplatedSemanticAgent.setup(config_sources, state)

      # Config lens should override base lens for same module
      lenses_update =
        Enum.find_value(diff, fn
          {:add_or_update, %{lenses: lenses}} -> lenses
          _ -> nil
        end)

      assert lenses_update != nil
      # Should have both lenses, with SameLens having the override config
      assert ["SameLens", %{config: "override"}] in lenses_update
      assert ["OtherLens", %{}] in lenses_update
    end

    test "setup without template or lenses saves base lenses for first call" do
      config_sources = %{
        static: %{},
        runtime: %{}
      }

      state = %{context: %{lenses: ["ExistingLens"]}}

      {:ok, diff} = TemplatedSemanticAgent.setup(config_sources, state)

      # First call without config lenses saves the base for later restoration
      assert diff == [{:add_or_update, %{_routine_base_lenses: ["ExistingLens"]}}]
    end

    test "setup without template or lenses restores base on subsequent call" do
      config_sources = %{
        static: %{},
        runtime: %{}
      }

      # Simulate second call where base was already saved
      state = %{
        context: %{
          lenses: ["ModifiedLens"],
          _routine_base_lenses: ["OriginalLens"]
        }
      }

      {:ok, diff} = TemplatedSemanticAgent.setup(config_sources, state)

      # Should restore to saved base
      assert diff == [{:add_or_update, %{lenses: ["OriginalLens"]}}]
    end

    test "check_condition functions work correctly" do
      assert TemplatedSemanticAgent.check_condition(:always, %{})

      assert TemplatedSemanticAgent.check_condition(:when_has_tool_calls, %{
               tool_calls: [%{name: "test"}]
             })

      refute TemplatedSemanticAgent.check_condition(:when_has_tool_calls, %{tool_calls: []})

      refute TemplatedSemanticAgent.check_condition(:when_no_tool_calls, %{
               tool_calls: [%{name: "test"}]
             })

      assert TemplatedSemanticAgent.check_condition(:when_no_tool_calls, %{tool_calls: []})

      assert TemplatedSemanticAgent.check_condition(:when_has_more_tools, %{
               to_execute: [%{name: "test"}]
             })

      refute TemplatedSemanticAgent.check_condition(:when_has_more_tools, %{to_execute: []})

      refute TemplatedSemanticAgent.check_condition(:when_tools_complete, %{
               to_execute: [%{name: "test"}]
             })

      assert TemplatedSemanticAgent.check_condition(:when_tools_complete, %{to_execute: []})
    end
  end

  describe "SemanticTransition lens" do
    setup do
      # Mock state with execution stack
      parent_routine = TestParentRoutine
      parent_step = :routing

      routine_definition = %{
        routing: %{
          type: TemplatedSemanticAgent,
          transitions: [
            {:option_a, "First option description"},
            {:option_b, "Second option description"},
            {:option_c, "Third option description"}
          ]
        }
      }

      state = %{
        execution_stack: [
          %{module: parent_routine, step: parent_step}
        ],
        routine_definitions: %{
          parent_routine => routine_definition
        }
      }

      {:ok, state: state}
    end

    test "provide_context formats semantic transitions", %{state: state} do
      context_blocks = SemanticTransition.provide_context(state)

      assert length(context_blocks) == 1
      [block] = context_blocks

      assert block.type == "text"
      assert block.text =~ "Available Transitions"
      assert block.text =~ "**option_a** → First option description"
      assert block.text =~ "**option_b** → Second option description"
      assert block.text =~ "**option_c** → Third option description"
      assert block.text =~ "choose_transition"
    end

    test "tools returns choose_transition tool" do
      tools = SemanticTransition.tools(%{})

      assert length(tools) == 1
      assert [{Koalemos.Lenses.SemanticTransition, :choose_transition}] = tools
    end

    test "info generates dynamic tool schema from context", %{state: state} do
      # Build context from state
      context = %{
        execution_stack: state.execution_stack,
        routine_definitions: state.routine_definitions
      }

      tool_info = SemanticTransition.info(:choose_transition, context)

      assert tool_info.name == "choose_transition"
      assert tool_info.description =~ "workflow transition"

      # Enum should contain transition names
      enum = get_in(tool_info, [:input_schema, :properties, :transition, :enum])
      assert "option_a" in enum
      assert "option_b" in enum
      assert "option_c" in enum
      assert length(enum) == 3
    end

    test "execute returns workflow_transition in lens state" do
      params = %{
        "transition" => "option_b",
        "reason" => "This is the best choice because..."
      }

      {message, lens_state} = SemanticTransition.execute(:choose_transition, params, %{})

      assert message =~ "Transitioning to: option_b"

      assert lens_state == [
               workflow_transition: {:option_b, "This is the best choice because..."}
             ]
    end

    test "handles empty execution stack gracefully" do
      empty_state = %{
        execution_stack: [],
        routine_definitions: %{}
      }

      # Should return empty context when no parent
      context_blocks = SemanticTransition.provide_context(empty_state)
      assert context_blocks == []

      # tools() still returns the tool definition
      tools = SemanticTransition.tools(%{})
      assert length(tools) == 1

      # But info returns fallback schema with warning
      empty_context = %{execution_stack: [], routine_definitions: %{}}
      tool_info = SemanticTransition.info(:choose_transition, empty_context)
      assert tool_info.name == "choose_transition"
      assert tool_info.description =~ "unavailable"
    end

    test "filters out non-semantic transitions" do
      # Mix of string (semantic) and atom (regular) conditions
      routine_definition = %{
        routing: %{
          type: TemplatedSemanticAgent,
          transitions: [
            {:option_a, "Semantic option"},
            {:option_b, :regular_condition},
            {:option_c, "Another semantic option"}
          ]
        }
      }

      context = %{
        execution_stack: [%{module: TestRoutine, step: :routing}],
        routine_definitions: %{TestRoutine => routine_definition}
      }

      tool_info = SemanticTransition.info(:choose_transition, context)
      enum = get_in(tool_info, [:input_schema, :properties, :transition, :enum])

      # Should only include semantic transitions
      assert "option_a" in enum
      assert "option_c" in enum
      refute "option_b" in enum
      assert length(enum) == 2
    end
  end

  describe "readonly lens configuration" do
    test "WireframeEditor returns no tools in readonly mode" do
      alias WireframeEditorWeb.Lenses.WireframeEditor

      # Normal mode - returns all tools
      normal_tools = WireframeEditor.tools(%{})
      assert length(normal_tools) == 9

      # Readonly mode - returns no tools
      readonly_tools = WireframeEditor.tools(%{readonly: true})
      assert readonly_tools == []
    end

    test "SequentialThinking always returns tools regardless of config" do
      alias Koalemos.Lenses.SequentialThinking

      # Normal mode
      normal_tools = SequentialThinking.tools(%{})
      assert length(normal_tools) == 1

      # With config (ignored, still returns tools)
      config_tools = SequentialThinking.tools(%{readonly: true})
      assert length(config_tools) == 1
    end
  end

  describe "integration with Engine" do
    test "workflow_transition mechanism is available in Orchestrator" do
      # This test verifies the Engine has the workflow_transition handling
      # The actual logic is in Orchestrator.handle_step_success (lines 219-251)

      # Verify the Orchestrator module exists and can be loaded
      alias Koalemos.Engine.Orchestrator

      assert Code.ensure_loaded?(Orchestrator)

      # Verify it has the public interface we expect
      # The workflow_transition handling is in the private handle_step_success/2
      # which is called by the Engine GenServer when a step completes
      assert Orchestrator.__info__(:functions) |> Keyword.has_key?(:execute_current_step)
      assert Orchestrator.__info__(:functions) |> Keyword.has_key?(:get_current_step_config)
    end
  end
end
