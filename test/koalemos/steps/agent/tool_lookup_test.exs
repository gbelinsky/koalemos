defmodule Koalemos.Steps.Agent.ToolLookupTest do
  use ExUnit.Case, async: true
  alias Koalemos.Steps.Agent.ToolLookup

  # Test helper module
  defmodule TestLens do
    def execute(:test_tool, _input, _context) do
      {"Tool executed", []}
    end
  end

  describe "execute/2 - valid tool calls" do
    test "resolves single valid tool call" do
      state = %{
        routine_id: "routine-123",
        context: %{
          tool_calls: [
            %{id: "call_1", name: "test_tool", input: %{arg: "value"}}
          ],
          tool_map: %{
            "test_tool" => {TestLens, :test_tool}
          }
        }
      }

      assert {:ok, diff} = ToolLookup.execute(%{}, state)
      assert diff[:remove] == [:tool_calls]
      assert [%{id: "call_1", module: TestLens, function: :test_tool}] = diff[:add_or_update][:to_execute]
    end

    test "resolves multiple valid tool calls" do
      state = %{
        routine_id: "routine-123",
        context: %{
          tool_calls: [
            %{id: "call_1", name: "tool_one", input: %{}},
            %{id: "call_2", name: "tool_two", input: %{}}
          ],
          tool_map: %{
            "tool_one" => {TestLens, :tool_one},
            "tool_two" => {TestLens, :tool_two}
          }
        }
      }

      assert {:ok, diff} = ToolLookup.execute(%{}, state)
      assert length(diff[:add_or_update][:to_execute]) == 2

      tools = diff[:add_or_update][:to_execute]
      assert Enum.any?(tools, fn t -> t.id == "call_1" && t.function == :tool_one end)
      assert Enum.any?(tools, fn t -> t.id == "call_2" && t.function == :tool_two end)
    end

    test "preserves tool call input" do
      input_data = %{param1: "value1", param2: 42}

      state = %{
        routine_id: "routine-123",
        context: %{
          tool_calls: [
            %{id: "call_1", name: "test_tool", input: input_data}
          ],
          tool_map: %{
            "test_tool" => {TestLens, :test_tool}
          }
        }
      }

      assert {:ok, diff} = ToolLookup.execute(%{}, state)
      [tool] = diff[:add_or_update][:to_execute]
      assert tool.input == input_data
    end
  end

  describe "execute/2 - invalid tool calls" do
    test "returns error message for unknown tool" do
      state = %{
        routine_id: "routine-123",
        context: %{
          tool_calls: [
            %{id: "call_1", name: "unknown_tool", input: %{}}
          ],
          tool_map: %{
            "valid_tool" => {TestLens, :valid_tool}
          }
        }
      }

      assert {:ok, diff} = ToolLookup.execute(%{}, state)

      # Should have error message appended
      assert Keyword.has_key?(diff, :append_to)
      [error_message] = diff[:append_to][:messages]

      assert error_message.role == "user"
      [content] = error_message.content
      assert content.type == "tool_result"
      assert content.tool_use_id == "call_1"
      assert content.content =~ "Tool 'unknown_tool' not found"
      assert content.content =~ "Available tools: valid_tool"
      assert content.is_error == true
    end

    test "lists all available tools in error message" do
      state = %{
        routine_id: "routine-123",
        context: %{
          tool_calls: [
            %{id: "call_1", name: "wrong_tool", input: %{}}
          ],
          tool_map: %{
            "tool_a" => {TestLens, :tool_a},
            "tool_b" => {TestLens, :tool_b},
            "tool_c" => {TestLens, :tool_c}
          }
        }
      }

      assert {:ok, diff} = ToolLookup.execute(%{}, state)
      [error_message] = diff[:append_to][:messages]
      [content] = error_message.content

      assert content.content =~ "tool_a"
      assert content.content =~ "tool_b"
      assert content.content =~ "tool_c"
    end

    test "separates valid and invalid tool calls" do
      state = %{
        routine_id: "routine-123",
        context: %{
          tool_calls: [
            %{id: "call_1", name: "valid_tool", input: %{}},
            %{id: "call_2", name: "invalid_tool", input: %{}},
            %{id: "call_3", name: "another_valid_tool", input: %{}}
          ],
          tool_map: %{
            "valid_tool" => {TestLens, :valid_tool},
            "another_valid_tool" => {TestLens, :another_valid_tool}
          }
        }
      }

      assert {:ok, diff} = ToolLookup.execute(%{}, state)

      # Should have 2 valid tools
      assert length(diff[:add_or_update][:to_execute]) == 2

      # Should have 1 error message
      assert length(diff[:append_to][:messages]) == 1
      [error_message] = diff[:append_to][:messages]
      [content] = error_message.content
      assert content.tool_use_id == "call_2"
    end
  end

  describe "execute/2 - edge cases" do
    test "handles empty tool_calls list" do
      state = %{
        routine_id: "routine-123",
        context: %{
          tool_calls: [],
          tool_map: %{"test_tool" => {TestLens, :test_tool}}
        }
      }

      assert {:ok, diff} = ToolLookup.execute(%{}, state)
      assert diff == [add_or_update: %{to_execute: []}]
      refute Keyword.has_key?(diff, :remove)
    end

    test "handles missing tool_calls key" do
      state = %{
        routine_id: "routine-123",
        context: %{
          tool_map: %{"test_tool" => {TestLens, :test_tool}}
        }
      }

      assert {:ok, diff} = ToolLookup.execute(%{}, state)
      assert diff == [add_or_update: %{to_execute: []}]
    end

    test "returns error when tool_map is empty" do
      state = %{
        routine_id: "routine-123",
        context: %{
          tool_calls: [%{id: "call_1", name: "test_tool", input: %{}}],
          tool_map: %{}
        }
      }

      assert {:error, error_msg} = ToolLookup.execute(%{}, state)
      assert error_msg == "No tool map available for tool lookup"
    end

    test "returns error when tool_map is missing" do
      state = %{
        routine_id: "routine-123",
        context: %{
          tool_calls: [%{id: "call_1", name: "test_tool", input: %{}}]
        }
      }

      assert {:error, error_msg} = ToolLookup.execute(%{}, state)
      assert error_msg == "No tool map available for tool lookup"
    end
  end

  describe "execute/2 - metadata" do
    test "includes routine_id in error messages" do
      state = %{
        routine_id: "custom-routine-456",
        context: %{
          tool_calls: [%{id: "call_1", name: "unknown_tool", input: %{}}],
          tool_map: %{"valid_tool" => {TestLens, :valid_tool}}
        }
      }

      assert {:ok, diff} = ToolLookup.execute(%{}, state)
      [error_message] = diff[:append_to][:messages]

      assert error_message.metadata.routine_id == "custom-routine-456"
      assert error_message.metadata.source == :tool_result
    end
  end
end
