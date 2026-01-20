defmodule Koalemos.Steps.Agent.StructuredResponseAgentTest do
  use ExUnit.Case, async: true

  alias Koalemos.Steps.Agent.StructuredResponseAgent
  alias Koalemos.Steps.Agent.StructuredResponseAgent.{CheckResponse, CaptureResult}

  describe "routine_definition/0" do
    test "returns routine with expected steps" do
      definition = StructuredResponseAgent.routine_definition()

      assert Map.has_key?(definition, :start)
      assert Map.has_key?(definition, :render_lens)
      assert Map.has_key?(definition, :llm_request)
      assert Map.has_key?(definition, :parse_response)
      assert Map.has_key?(definition, :tool_lookup)
      assert Map.has_key?(definition, :tool_execution)
      assert Map.has_key?(definition, :check_response)
      assert Map.has_key?(definition, :capture_result)
    end

    test "start step is ToolSchema type" do
      definition = StructuredResponseAgent.routine_definition()

      assert definition.start.type == Koalemos.Steps.Agent.ToolSchema
    end

    test "check_response transitions to capture_result when has response" do
      definition = StructuredResponseAgent.routine_definition()

      transitions = definition.check_response.transitions
      assert {:capture_result, :when_has_response} in transitions
      assert {:start, :when_no_response} in transitions
    end

    test "capture_result transitions to end" do
      definition = StructuredResponseAgent.routine_definition()

      assert definition.capture_result.transitions == [{:end, :always}]
    end
  end

  describe "check_condition/2" do
    test ":always returns true" do
      assert StructuredResponseAgent.check_condition(:always, %{})
    end

    test ":when_has_tool_calls with tool calls" do
      context = %{tool_calls: [%{name: "test"}]}
      assert StructuredResponseAgent.check_condition(:when_has_tool_calls, context)
    end

    test ":when_has_tool_calls without tool calls" do
      context = %{tool_calls: []}
      refute StructuredResponseAgent.check_condition(:when_has_tool_calls, context)
    end

    test ":when_has_tool_calls with nil" do
      context = %{}
      refute StructuredResponseAgent.check_condition(:when_has_tool_calls, context)
    end

    test ":when_no_tool_calls without tool calls" do
      context = %{tool_calls: []}
      assert StructuredResponseAgent.check_condition(:when_no_tool_calls, context)
    end

    test ":when_no_tool_calls with tool calls" do
      context = %{tool_calls: [%{name: "test"}]}
      refute StructuredResponseAgent.check_condition(:when_no_tool_calls, context)
    end

    test ":when_has_more_tools with pending tools" do
      context = %{to_execute: [%{name: "tool1"}]}
      assert StructuredResponseAgent.check_condition(:when_has_more_tools, context)
    end

    test ":when_has_more_tools without pending tools" do
      context = %{to_execute: []}
      refute StructuredResponseAgent.check_condition(:when_has_more_tools, context)
    end

    test ":when_tools_complete when empty" do
      context = %{to_execute: []}
      assert StructuredResponseAgent.check_condition(:when_tools_complete, context)
    end

    test ":when_tools_complete when has pending" do
      context = %{to_execute: [%{name: "tool1"}]}
      refute StructuredResponseAgent.check_condition(:when_tools_complete, context)
    end

    test ":when_has_response with structured_response in lens_state" do
      context = %{lens_state: %{structured_response: %{"summary" => "test"}}}
      assert StructuredResponseAgent.check_condition(:when_has_response, context)
    end

    test ":when_has_response without structured_response" do
      context = %{lens_state: %{}}
      refute StructuredResponseAgent.check_condition(:when_has_response, context)
    end

    test ":when_has_response with nil lens_state" do
      context = %{}
      refute StructuredResponseAgent.check_condition(:when_has_response, context)
    end

    test ":when_no_response without structured_response" do
      context = %{lens_state: %{}}
      assert StructuredResponseAgent.check_condition(:when_no_response, context)
    end

    test ":when_no_response with structured_response" do
      context = %{lens_state: %{structured_response: %{}}}
      refute StructuredResponseAgent.check_condition(:when_no_response, context)
    end
  end

  describe "setup/2" do
    test "adds StructuredResponse lens with schema" do
      config_sources = %{
        static: %{
          schema: %{
            name: %{type: :string}
          }
        },
        runtime: %{}
      }

      state = %{context: %{lenses: []}}

      {:ok, diff} = StructuredResponseAgent.setup(config_sources, state)

      # Find the lenses update
      lens_update =
        Enum.find_value(diff, fn
          {:add_or_update, %{lenses: lenses}} -> lenses
          _ -> nil
        end)

      assert lens_update != nil

      # Check that StructuredResponse lens is present with schema
      structured_lens =
        Enum.find(lens_update, fn
          ["Koalemos.Lenses.StructuredResponse", _config] -> true
          _ -> false
        end)

      assert structured_lens != nil
      ["Koalemos.Lenses.StructuredResponse", lens_config] = structured_lens
      assert lens_config.schema == %{name: %{type: :string}}
    end

    test "uses default tool name" do
      config_sources = %{
        static: %{schema: %{}},
        runtime: %{}
      }

      state = %{context: %{lenses: []}}

      {:ok, diff} = StructuredResponseAgent.setup(config_sources, state)

      lens_update =
        Enum.find_value(diff, fn
          {:add_or_update, %{lenses: lenses}} -> lenses
          _ -> nil
        end)

      ["Koalemos.Lenses.StructuredResponse", lens_config] =
        Enum.find(lens_update, fn
          ["Koalemos.Lenses.StructuredResponse", _] -> true
          _ -> false
        end)

      assert lens_config.tool_name == "respond"
    end

    test "uses custom tool name" do
      config_sources = %{
        static: %{
          schema: %{},
          tool_name: "submit_analysis"
        },
        runtime: %{}
      }

      state = %{context: %{lenses: []}}

      {:ok, diff} = StructuredResponseAgent.setup(config_sources, state)

      lens_update =
        Enum.find_value(diff, fn
          {:add_or_update, %{lenses: lenses}} -> lenses
          _ -> nil
        end)

      ["Koalemos.Lenses.StructuredResponse", lens_config] =
        Enum.find(lens_update, fn
          ["Koalemos.Lenses.StructuredResponse", _] -> true
          _ -> false
        end)

      assert lens_config.tool_name == "submit_analysis"
    end

    test "stores output_key" do
      config_sources = %{
        static: %{
          schema: %{},
          output_key: :analysis_result
        },
        runtime: %{}
      }

      state = %{context: %{lenses: []}}

      {:ok, diff} = StructuredResponseAgent.setup(config_sources, state)

      output_key_update =
        Enum.find_value(diff, fn
          {:add_or_update, %{_structured_output_key: key}} -> key
          _ -> nil
        end)

      assert output_key_update == :analysis_result
    end

    test "uses default output_key when not specified" do
      config_sources = %{
        static: %{schema: %{}},
        runtime: %{}
      }

      state = %{context: %{lenses: []}}

      {:ok, diff} = StructuredResponseAgent.setup(config_sources, state)

      output_key_update =
        Enum.find_value(diff, fn
          {:add_or_update, %{_structured_output_key: key}} -> key
          _ -> nil
        end)

      assert output_key_update == :structured_output
    end

    test "renders template to step_system_prompt" do
      config_sources = %{
        static: %{
          schema: %{},
          template: "Analyze the following: <%= @context[:input] %>"
        },
        runtime: %{}
      }

      state = %{context: %{lenses: [], input: "test input"}}

      {:ok, diff} = StructuredResponseAgent.setup(config_sources, state)

      prompt_update =
        Enum.find_value(diff, fn
          {:add_or_update, %{step_system_prompt: prompt}} -> prompt
          _ -> nil
        end)

      assert prompt_update == "Analyze the following: test input"
    end

    test "merges with existing lenses" do
      config_sources = %{
        static: %{
          schema: %{},
          lenses: ["SomeOther.Lens"]
        },
        runtime: %{}
      }

      state = %{context: %{lenses: ["Existing.Lens"]}}

      {:ok, diff} = StructuredResponseAgent.setup(config_sources, state)

      lens_update =
        Enum.find_value(diff, fn
          {:add_or_update, %{lenses: lenses}} -> lenses
          _ -> nil
        end)

      # Should have StructuredResponse + configured + base lenses
      lens_names =
        Enum.map(lens_update, fn
          [name, _config] -> name
          name -> name
        end)

      assert "Koalemos.Lenses.StructuredResponse" in lens_names
      assert "SomeOther.Lens" in lens_names
      assert "Existing.Lens" in lens_names
    end

    test "handles template rendering error gracefully" do
      config_sources = %{
        static: %{
          schema: %{},
          template: "<%= @context.nonexistent.field %>"
        },
        runtime: %{}
      }

      state = %{context: %{lenses: []}}

      {:ok, diff} = StructuredResponseAgent.setup(config_sources, state)

      prompt_update =
        Enum.find_value(diff, fn
          {:add_or_update, %{step_system_prompt: prompt}} -> prompt
          _ -> nil
        end)

      assert prompt_update =~ "Template rendering failed"
    end

    test "adds custom tool_description" do
      config_sources = %{
        static: %{
          schema: %{},
          tool_description: "Custom description for the tool"
        },
        runtime: %{}
      }

      state = %{context: %{lenses: []}}

      {:ok, diff} = StructuredResponseAgent.setup(config_sources, state)

      lens_update =
        Enum.find_value(diff, fn
          {:add_or_update, %{lenses: lenses}} -> lenses
          _ -> nil
        end)

      ["Koalemos.Lenses.StructuredResponse", lens_config] =
        Enum.find(lens_update, fn
          ["Koalemos.Lenses.StructuredResponse", _] -> true
          _ -> false
        end)

      assert lens_config.tool_description == "Custom description for the tool"
    end
  end

  describe "CheckResponse.execute/2" do
    test "returns ok with empty diff" do
      {:ok, diff} = CheckResponse.execute(%{}, %{context: %{}})

      assert diff == []
    end
  end

  describe "CaptureResult.execute/2" do
    test "captures structured_response to configured output_key" do
      state = %{
        context: %{
          lens_state: %{structured_response: %{"summary" => "test result"}},
          _structured_output_key: :my_result
        }
      }

      {:ok, diff} = CaptureResult.execute(%{}, state)

      assert {:add_or_update, %{my_result: %{"summary" => "test result"}}} in diff
      assert {:remove, [:_structured_output_key]} in diff
    end

    test "uses default output_key when not specified" do
      state = %{
        context: %{
          lens_state: %{structured_response: %{"data" => 123}}
        }
      }

      {:ok, diff} = CaptureResult.execute(%{}, state)

      assert {:add_or_update, %{structured_output: %{"data" => 123}}} in diff
    end

    test "returns empty diff when no structured_response" do
      state = %{
        context: %{
          lens_state: %{},
          _structured_output_key: :result
        }
      }

      {:ok, diff} = CaptureResult.execute(%{}, state)

      assert diff == []
    end

    test "handles nil lens_state" do
      state = %{context: %{}}

      {:ok, diff} = CaptureResult.execute(%{}, state)

      assert diff == []
    end

    test "preserves complex nested result" do
      complex_result = %{
        "summary" => "A test",
        "items" => [%{"name" => "a"}, %{"name" => "b"}],
        "metadata" => %{"version" => "1.0", "count" => 42}
      }

      state = %{
        context: %{
          lens_state: %{structured_response: complex_result},
          _structured_output_key: :analysis
        }
      }

      {:ok, diff} = CaptureResult.execute(%{}, state)

      assert {:add_or_update, %{analysis: ^complex_result}} = List.keyfind(diff, :add_or_update, 0)
    end
  end
end
