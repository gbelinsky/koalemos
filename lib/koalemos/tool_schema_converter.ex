defmodule Koalemos.ToolSchemaConverter do
  @moduledoc """
  Converts tool schemas between Anthropic and OpenAI/Ollama formats.

  ## Anthropic Format

  ```elixir
  %{
    name: "tool_name",
    description: "Tool description",
    input_schema: %{
      type: "object",
      properties: %{...},
      required: [...]
    }
  }
  ```

  ## OpenAI/Ollama Format

  ```elixir
  %{
    "type" => "function",
    "function" => %{
      "name" => "tool_name",
      "description" => "Tool description",
      "parameters" => %{
        "type" => "object",
        "properties" => %{...},
        "required" => [...]
      }
    }
  }
  ```

  ## Usage

      iex> tools = [%{name: "get_weather", description: "Get weather", input_schema: %{type: "object"}}]
      iex> [result] = Koalemos.ToolSchemaConverter.anthropic_to_openai(tools)
      iex> result["type"]
      "function"
      iex> result["function"]["name"]
      "get_weather"
  """

  @doc """
  Convert a list of Anthropic tool schemas to OpenAI/Ollama format.

  Handles both atom and string keys in input.

  ## Examples

      iex> tools = [%{name: "test", description: "A test tool", input_schema: %{type: "object"}}]
      iex> [result] = Koalemos.ToolSchemaConverter.anthropic_to_openai(tools)
      iex> result["type"]
      "function"
      iex> result["function"]["name"]
      "test"

      iex> tools = [%{"name" => "test", "description" => "desc", "input_schema" => %{}}]
      iex> [result] = Koalemos.ToolSchemaConverter.anthropic_to_openai(tools)
      iex> result["function"]["name"]
      "test"
  """
  def anthropic_to_openai(anthropic_tools) when is_list(anthropic_tools) do
    Enum.map(anthropic_tools, &convert_single_tool/1)
  end

  # Convert a single tool from Anthropic to OpenAI format
  defp convert_single_tool(tool) do
    # Handle both atom and string keys
    name = tool["name"] || tool[:name]
    description = tool["description"] || tool[:description]
    input_schema = tool["input_schema"] || tool[:input_schema]

    %{
      "type" => "function",
      "function" => %{
        "name" => name,
        "description" => description,
        "parameters" => input_schema
      }
    }
  end
end
