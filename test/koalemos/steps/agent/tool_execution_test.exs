defmodule Koalemos.Steps.Agent.ToolExecutionTest do
  use ExUnit.Case, async: true
  alias Koalemos.Steps.Agent.ToolExecution

  # Test helper module
  defmodule TestTools do
    def simple_tool(_input, _context) do
      "Simple result"
    end

    def tool_with_lens_updates(_input, _context) do
      {"Result with updates", [key1: "value1", key2: "value2"]}
    end

    def tool_with_metadata(_input, _context) do
      {"Result with metadata", [lens_key: "lens_value"], %{custom: "metadata"}}
    end

    def failing_tool(_input, _context) do
      raise "Intentional failure"
    end

    def execute(:legacy_tool, _input, _context) do
      "Legacy tool result"
    end
  end

  describe "execute/2 - basic tool execution" do
    test "executes single tool and returns result" do
      state = %{
        routine_id: "routine-123",
        context: %{
          to_execute: [
            %{id: "call_1", module: TestTools, function: :simple_tool, input: %{}}
          ]
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)

      # Should append message
      assert Keyword.has_key?(diff, :append_to)
      [message] = diff[:append_to][:messages]

      assert message.role == "user"
      [content] = message.content
      assert content.type == "tool_result"
      assert content.tool_use_id == "call_1"
      assert content.content == "Simple result"

      # Should update queue (remove executed tool)
      assert diff[:add_or_update][:to_execute] == []
    end

    test "processes queue one at a time (consume pattern)" do
      state = %{
        routine_id: "routine-123",
        context: %{
          to_execute: [
            %{id: "call_1", module: TestTools, function: :simple_tool, input: %{}},
            %{id: "call_2", module: TestTools, function: :simple_tool, input: %{}},
            %{id: "call_3", module: TestTools, function: :simple_tool, input: %{}}
          ]
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)

      # Should only execute first tool
      [message] = diff[:append_to][:messages]
      [content] = message.content
      assert content.tool_use_id == "call_1"

      # Queue should have 2 remaining
      assert length(diff[:add_or_update][:to_execute]) == 2
    end

    test "uses legacy execute/3 interface if function/2 not available" do
      state = %{
        routine_id: "routine-123",
        context: %{
          to_execute: [
            %{id: "call_1", module: TestTools, function: :legacy_tool, input: %{}}
          ]
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)
      [message] = diff[:append_to][:messages]
      [content] = message.content
      assert content.content == "Legacy tool result"
    end

    test "passes routine_id in enhanced context to tools" do
      defmodule ContextCheckTool do
        def check_context(_input, context) do
          routine_id = context[:routine_id]
          "routine_id=#{routine_id}"
        end
      end

      state = %{
        routine_id: "custom-routine-456",
        context: %{
          to_execute: [
            %{id: "call_1", module: ContextCheckTool, function: :check_context, input: %{}}
          ]
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)
      [message] = diff[:append_to][:messages]
      [content] = message.content
      assert content.content == "routine_id=custom-routine-456"
    end
  end

  describe "execute/2 - tool result formats" do
    test "handles simple string result" do
      state = %{
        routine_id: "routine-123",
        context: %{
          to_execute: [
            %{id: "call_1", module: TestTools, function: :simple_tool, input: %{}}
          ]
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)
      [message] = diff[:append_to][:messages]
      [content] = message.content
      assert content.content == "Simple result"
    end

    test "handles result with lens updates" do
      state = %{
        routine_id: "routine-123",
        context: %{
          to_execute: [
            %{id: "call_1", module: TestTools, function: :tool_with_lens_updates, input: %{}}
          ]
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)

      # Should have lens_state updates
      lens_updates = Keyword.get_values(diff, :add_or_update)
      lens_state_update = Enum.find(lens_updates, fn update -> Map.has_key?(update, :lens_state) end)

      assert lens_state_update.lens_state.key1 == "value1"
      assert lens_state_update.lens_state.key2 == "value2"
    end

    test "handles result with metadata" do
      state = %{
        routine_id: "routine-123",
        context: %{
          to_execute: [
            %{id: "call_1", module: TestTools, function: :tool_with_metadata, input: %{}}
          ]
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)

      # Should have lens_state update
      lens_updates = Keyword.get_values(diff, :add_or_update)
      lens_state_update = Enum.find(lens_updates, fn update -> Map.has_key?(update, :lens_state) end)
      assert lens_state_update.lens_state.lens_key == "lens_value"

      # Metadata is used internally but not exposed in diff
      [message] = diff[:append_to][:messages]
      [content] = message.content
      assert content.content == "Result with metadata"
    end
  end

  describe "execute/2 - lens state management" do
    test "merges lens updates with existing lens state" do
      state = %{
        routine_id: "routine-123",
        context: %{
          to_execute: [
            %{id: "call_1", module: TestTools, function: :tool_with_lens_updates, input: %{}}
          ],
          lens_state: %{existing_key: "existing_value"}
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)

      lens_updates = Keyword.get_values(diff, :add_or_update)
      lens_state_update = Enum.find(lens_updates, fn update -> Map.has_key?(update, :lens_state) end)

      # Should preserve existing and add new
      assert lens_state_update.lens_state.existing_key == "existing_value"
      assert lens_state_update.lens_state.key1 == "value1"
      assert lens_state_update.lens_state.key2 == "value2"
    end

    test "initializes lens_state if not present" do
      state = %{
        routine_id: "routine-123",
        context: %{
          to_execute: [
            %{id: "call_1", module: TestTools, function: :tool_with_lens_updates, input: %{}}
          ]
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)

      lens_updates = Keyword.get_values(diff, :add_or_update)
      lens_state_update = Enum.find(lens_updates, fn update -> Map.has_key?(update, :lens_state) end)

      assert lens_state_update.lens_state.key1 == "value1"
      assert lens_state_update.lens_state.key2 == "value2"
    end
  end

  describe "execute/2 - error handling" do
    test "catches and returns error message for failing tool" do
      state = %{
        routine_id: "routine-123",
        context: %{
          to_execute: [
            %{id: "call_1", module: TestTools, function: :failing_tool, input: %{}}
          ]
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)

      [message] = diff[:append_to][:messages]
      [content] = message.content
      assert content.content =~ "Tool execution failed"
      assert content.content =~ "Intentional failure"
    end

    test "returns error when to_execute is nil" do
      state = %{
        routine_id: "routine-123",
        context: %{}
      }

      assert {:error, error_msg} = ToolExecution.execute(%{}, state)
      assert error_msg == "No tool calls found in context"
    end

    test "cleans up empty queue" do
      state = %{
        routine_id: "routine-123",
        context: %{
          to_execute: []
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)
      assert diff == [remove: [:to_execute]]
    end
  end

  describe "execute/2 - content block results" do
    test "handles tool returning content blocks" do
      defmodule ContentBlockTool do
        def return_content_blocks(_input, _context) do
          {[{:text, "Text result"}, {:image, "base64data", "image/jpeg"}], []}
        end
      end

      state = %{
        routine_id: "routine-123",
        context: %{
          to_execute: [
            %{id: "call_1", module: ContentBlockTool, function: :return_content_blocks, input: %{}}
          ]
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)

      [message] = diff[:append_to][:messages]
      [content_block] = message.content
      assert content_block.type == "tool_result"

      # Content should be formatted content blocks, not string
      assert is_list(content_block.content)
      assert length(content_block.content) == 2

      [text_block, image_block] = content_block.content
      assert text_block.type == "text"
      assert text_block.text == "Text result"
      assert image_block.type == "image"
    end

    test "handles tool returning text only as content block" do
      defmodule TextOnlyContentBlockTool do
        def return_text_block(_input, _context) do
          {[{:text, "Just text"}], []}
        end
      end

      state = %{
        routine_id: "routine-123",
        context: %{
          to_execute: [
            %{id: "call_1", module: TextOnlyContentBlockTool, function: :return_text_block, input: %{}}
          ]
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)

      [message] = diff[:append_to][:messages]
      [content_block] = message.content
      assert is_list(content_block.content)
      [text_block] = content_block.content
      assert text_block.text == "Just text"
    end
  end

  describe "execute/2 - metadata" do
    test "includes routine_id in tool result messages" do
      state = %{
        routine_id: "custom-routine-789",
        context: %{
          to_execute: [
            %{id: "call_1", module: TestTools, function: :simple_tool, input: %{}}
          ]
        }
      }

      assert {:ok, diff} = ToolExecution.execute(%{}, state)
      [message] = diff[:append_to][:messages]

      assert message.metadata.routine_id == "custom-routine-789"
      assert message.metadata.source == :tool_result
    end
  end
end
