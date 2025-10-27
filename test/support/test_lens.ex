defmodule Koalemos.TestLens do
  @moduledoc """
  Simple test lens for integration testing.

  Provides:
  - Text context: "Test context from TestLens"
  - One tool: echo(message) → returns message
  - Optional image context (if :include_image in state.context)
  """

  @doc """
  Provide context blocks for this lens.

  Returns list of text/image blocks.
  """
  def provide_context(state) do
    text_blocks = [
      %{type: "text", text: "Test context from TestLens"}
    ]

    image_blocks =
      if Map.get(state.context, :include_test_image, false) do
        [
          %{
            type: "image",
            source: %{
              type: "base64",
              media_type: "image/png",
              data: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
            }
          }
        ]
      else
        []
      end

    text_blocks ++ image_blocks
  end

  @doc """
  Provide tool definitions for this lens.
  """
  def tools do
    [
      %{
        name: "echo",
        description: "Echo back a message",
        input_schema: %{
          type: "object",
          properties: %{
            message: %{
              type: "string",
              description: "The message to echo back"
            }
          },
          required: ["message"]
        }
      },
      %{
        name: "add",
        description: "Add two numbers together",
        input_schema: %{
          type: "object",
          properties: %{
            a: %{type: "number", description: "First number"},
            b: %{type: "number", description: "Second number"}
          },
          required: ["a", "b"]
        }
      },
      %{
        name: "fail",
        description: "Tool that always fails (for error testing)",
        input_schema: %{
          type: "object",
          properties: %{},
          required: []
        }
      }
    ]
  end

  @doc """
  Execute a tool call.

  Returns {:ok, result} or {:error, reason}
  """
  def execute_tool("echo", %{"message" => message}, _state) do
    {:ok, message}
  end

  def execute_tool("add", %{"a" => a, "b" => b}, _state) do
    {:ok, "#{a + b}"}
  end

  def execute_tool("fail", _args, _state) do
    {:error, "Tool deliberately failed"}
  end

  def execute_tool(tool_name, _args, _state) do
    {:error, "Unknown tool: #{tool_name}"}
  end
end
