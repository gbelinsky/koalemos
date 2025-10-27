defmodule Koalemos.Steps.Agent.ToolSchemaTest do
  use ExUnit.Case, async: true
  alias Koalemos.Steps.Agent.ToolSchema

  # Test helper lenses
  defmodule SimpleLens do
    def tools do
      [{__MODULE__, :test_tool}]
    end

    def info(:test_tool) do
      %{
        name: "test_tool",
        description: "A simple test tool",
        input_schema: %{type: "object", properties: %{}}
      }
    end
  end

  defmodule ContextAwareLens do
    def tools do
      [{__MODULE__, :context_tool}]
    end

    def info(:context_tool, context) do
      mode = context[:mode] || "default"
      %{
        name: "context_tool",
        description: "Tool with mode: #{mode}",
        input_schema: %{type: "object", properties: %{}}
      }
    end

    # Fallback for when context not provided
    def info(:context_tool) do
      %{
        name: "context_tool",
        description: "Tool with mode: default",
        input_schema: %{type: "object", properties: %{}}
      }
    end
  end

  defmodule MultiToolLens do
    def tools do
      [{__MODULE__, :tool_one}, {__MODULE__, :tool_two}]
    end

    def info(:tool_one) do
      %{name: "tool_one", description: "First tool", input_schema: %{}}
    end

    def info(:tool_two) do
      %{name: "tool_two", description: "Second tool", input_schema: %{}}
    end
  end

  defmodule LensWithoutTools do
    # Doesn't implement tools/0
  end

  describe "execute/2" do
    test "collects tools from single lens (string format)" do
      state = %{
        context: %{
          active_lenses: ["Koalemos.Steps.Agent.ToolSchemaTest.SimpleLens"]
        }
      }

      assert {:ok, diff} = ToolSchema.execute(%{}, state)
      assert [add_or_update: updates] = diff

      assert length(updates.tool_descriptions) == 1
      assert hd(updates.tool_descriptions).name == "test_tool"

      assert map_size(updates.tool_map) == 1
      assert updates.tool_map["test_tool"] == {SimpleLens, :test_tool}
    end

    test "collects tools from multiple lenses" do
      state = %{
        context: %{
          active_lenses: [
            "Koalemos.Steps.Agent.ToolSchemaTest.SimpleLens",
            "Koalemos.Steps.Agent.ToolSchemaTest.MultiToolLens"
          ]
        }
      }

      assert {:ok, diff} = ToolSchema.execute(%{}, state)
      assert [add_or_update: updates] = diff

      assert length(updates.tool_descriptions) == 3
      tool_names = Enum.map(updates.tool_descriptions, & &1.name)
      assert "test_tool" in tool_names
      assert "tool_one" in tool_names
      assert "tool_two" in tool_names

      assert map_size(updates.tool_map) == 3
    end

    test "uses list format with config" do
      state = %{
        context: %{
          active_lenses: [
            ["Koalemos.Steps.Agent.ToolSchemaTest.SimpleLens", %{some: "config"}]
          ]
        }
      }

      assert {:ok, diff} = ToolSchema.execute(%{}, state)
      assert [add_or_update: updates] = diff

      assert length(updates.tool_descriptions) == 1
      assert hd(updates.tool_descriptions).name == "test_tool"
    end

    test "uses context-aware info/2 when available" do
      state = %{
        context: %{
          active_lenses: ["Koalemos.Steps.Agent.ToolSchemaTest.ContextAwareLens"],
          mode: "advanced"
        }
      }

      assert {:ok, diff} = ToolSchema.execute(%{}, state)
      assert [add_or_update: updates] = diff

      description = hd(updates.tool_descriptions).description
      assert description == "Tool with mode: advanced"
    end

    test "falls back to info/1 for lenses without info/2" do
      state = %{
        context: %{
          active_lenses: ["Koalemos.Steps.Agent.ToolSchemaTest.SimpleLens"]
        }
      }

      assert {:ok, diff} = ToolSchema.execute(%{}, state)
      assert [add_or_update: updates] = diff

      assert hd(updates.tool_descriptions).name == "test_tool"
    end

    test "handles lens without tools/0 gracefully" do
      state = %{
        context: %{
          active_lenses: [
            "Koalemos.Steps.Agent.ToolSchemaTest.SimpleLens",
            "Koalemos.Steps.Agent.ToolSchemaTest.LensWithoutTools"
          ]
        }
      }

      # Should succeed but only get tools from SimpleLens
      assert {:ok, diff} = ToolSchema.execute(%{}, state)
      assert [add_or_update: updates] = diff

      assert length(updates.tool_descriptions) == 1
      assert hd(updates.tool_descriptions).name == "test_tool"
    end

    test "returns empty tools when no lenses configured" do
      state = %{context: %{}}

      assert {:ok, diff} = ToolSchema.execute(%{}, state)
      assert [add_or_update: updates] = diff

      assert updates.tool_descriptions == []
      assert updates.tool_map == %{}
    end

    test "uses active_lenses key first, then lenses key" do
      state = %{
        context: %{
          active_lenses: ["Koalemos.Steps.Agent.ToolSchemaTest.SimpleLens"],
          lenses: ["Koalemos.Steps.Agent.ToolSchemaTest.MultiToolLens"]
        }
      }

      # Should use active_lenses, not lenses
      assert {:ok, diff} = ToolSchema.execute(%{}, state)
      assert [add_or_update: updates] = diff

      assert length(updates.tool_descriptions) == 1
      assert hd(updates.tool_descriptions).name == "test_tool"
    end

    test "uses lenses key when active_lenses not present" do
      state = %{
        context: %{
          lenses: ["Koalemos.Steps.Agent.ToolSchemaTest.MultiToolLens"]
        }
      }

      assert {:ok, diff} = ToolSchema.execute(%{}, state)
      assert [add_or_update: updates] = diff

      assert length(updates.tool_descriptions) == 2
    end

    test "returns error when lens module not found" do
      state = %{
        context: %{
          active_lenses: ["NonExistent.Lens.Module"]
        }
      }

      assert {:error, error_msg} = ToolSchema.execute(%{}, state)
      assert error_msg =~ "Tool schema extraction failed"
      assert error_msg =~ "not an already existing atom"
    end

    test "builds correct tool_map structure" do
      state = %{
        context: %{
          active_lenses: ["Koalemos.Steps.Agent.ToolSchemaTest.MultiToolLens"]
        }
      }

      assert {:ok, diff} = ToolSchema.execute(%{}, state)
      assert [add_or_update: updates] = diff

      assert updates.tool_map["tool_one"] == {MultiToolLens, :tool_one}
      assert updates.tool_map["tool_two"] == {MultiToolLens, :tool_two}
    end

    test "tool_descriptions match tool_map keys" do
      state = %{
        context: %{
          active_lenses: ["Koalemos.Steps.Agent.ToolSchemaTest.MultiToolLens"]
        }
      }

      assert {:ok, diff} = ToolSchema.execute(%{}, state)
      assert [add_or_update: updates] = diff

      description_names = Enum.map(updates.tool_descriptions, & &1.name) |> MapSet.new()
      map_keys = Map.keys(updates.tool_map) |> MapSet.new()

      assert MapSet.equal?(description_names, map_keys)
    end
  end
end
