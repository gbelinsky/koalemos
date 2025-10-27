defmodule Koalemos.ToolSchemaConverterTest do
  use ExUnit.Case, async: true
  alias Koalemos.ToolSchemaConverter
  doctest Koalemos.ToolSchemaConverter

  describe "anthropic_to_openai/1" do
    test "converts single tool with atom keys" do
      anthropic_tools = [
        %{
          name: "get_weather",
          description: "Get weather for a location",
          input_schema: %{
            type: "object",
            properties: %{
              location: %{type: "string", description: "City name"}
            },
            required: ["location"]
          }
        }
      ]

      [result] = ToolSchemaConverter.anthropic_to_openai(anthropic_tools)

      assert result["type"] == "function"
      assert result["function"]["name"] == "get_weather"
      assert result["function"]["description"] == "Get weather for a location"

      # Parameters structure is preserved as-is
      params = result["function"]["parameters"]
      assert params.type == "object"
      assert params.required == ["location"]
    end

    test "converts single tool with string keys" do
      anthropic_tools = [
        %{
          "name" => "calculate",
          "description" => "Perform calculation",
          "input_schema" => %{
            "type" => "object",
            "properties" => %{
              "expression" => %{"type" => "string"}
            }
          }
        }
      ]

      [result] = ToolSchemaConverter.anthropic_to_openai(anthropic_tools)

      assert result["type"] == "function"
      assert result["function"]["name"] == "calculate"
      assert result["function"]["description"] == "Perform calculation"
      assert result["function"]["parameters"]["type"] == "object"
    end

    test "converts multiple tools" do
      anthropic_tools = [
        %{
          name: "tool1",
          description: "First tool",
          input_schema: %{type: "object"}
        },
        %{
          name: "tool2",
          description: "Second tool",
          input_schema: %{type: "object"}
        },
        %{
          name: "tool3",
          description: "Third tool",
          input_schema: %{type: "object"}
        }
      ]

      results = ToolSchemaConverter.anthropic_to_openai(anthropic_tools)

      assert length(results) == 3
      assert Enum.at(results, 0)["function"]["name"] == "tool1"
      assert Enum.at(results, 1)["function"]["name"] == "tool2"
      assert Enum.at(results, 2)["function"]["name"] == "tool3"
    end

    test "handles empty tool list" do
      assert ToolSchemaConverter.anthropic_to_openai([]) == []
    end

    test "handles mixed atom and string keys" do
      anthropic_tools = [
        %{
          "name" => "mixed_tool",
          "input_schema" => %{
            "properties" => %{},
            type: "object"
          },
          description: "Tool with mixed keys"
        }
      ]

      [result] = ToolSchemaConverter.anthropic_to_openai(anthropic_tools)

      assert result["type"] == "function"
      assert result["function"]["name"] == "mixed_tool"
      assert result["function"]["description"] == "Tool with mixed keys"
    end

    test "preserves complex input schema structure" do
      anthropic_tools = [
        %{
          name: "complex_tool",
          description: "Tool with complex schema",
          input_schema: %{
            type: "object",
            properties: %{
              items: %{
                type: "array",
                items: %{
                  type: "object",
                  properties: %{
                    name: %{type: "string"},
                    value: %{type: "number"}
                  },
                  required: ["name"]
                }
              },
              metadata: %{
                type: "object",
                additionalProperties: true
              }
            },
            required: ["items"]
          }
        }
      ]

      [result] = ToolSchemaConverter.anthropic_to_openai(anthropic_tools)

      # Verify nested structure is preserved (with atom keys)
      params = result["function"]["parameters"]
      assert params.properties.items.type == "array"
      assert params.properties.items.items.type == "object"
      assert params.required == ["items"]
    end
  end
end
