defmodule Koalemos.Lenses.TestLensScreenshot do
  @moduledoc """
  Simple test lens for integration testing.

  Provides:
  - Text context: "Test context from TestLens"
  - One tool: echo(message) → returns message
  - Optional image context (if :include_image in state.context)
  - Screenshot integration (M3 Sprint 3) via :request_screenshot flag
  """
  require Logger

  alias Koalemos.Lenses.Helpers.ScreenshotCapture

  @doc """
  Provide context blocks for this lens.

  Returns list of text/image blocks.

  ## Screenshot Integration (M3 Sprint 3)

  If `state.lens_state[:request_screenshot]` is true:
  - Triggers screenshot capture via PubSub
  - Waits for capture to complete (5 second timeout)
  - Retrieves from ScreenshotCache
  - Includes screenshot as image content block
  """
  def provide_context(state) do
    text_blocks = [
      %{type: "text", text: "Test context from TestLens"}
    ]

    # Legacy test image support
    legacy_image_blocks =
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

    # M3 Sprint 3: Screenshot integration via lens_state flag
    lens_state = Map.get(state.context, :lens_state, %{})

    screenshot_blocks =
      if Map.get(lens_state, :request_screenshot, false) do
        routine_id = Map.get(state, :routine_id)

        case ScreenshotCapture.capture(routine_id) do
          {:ok, image_block} ->
            [image_block]

          {:error, reason} ->
            Logger.warning("[TestLens] Failed to capture screenshot: #{inspect(reason)}")
            []
        end
      else
        []
      end

    text_blocks ++ legacy_image_blocks ++ screenshot_blocks
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

  ## echo Tool

  Special behavior for testing (M3 Sprint 3):
  - If message contains "screenshot", sets :request_screenshot flag
  - This triggers screenshot capture on next provide_context() call
  """
  def execute_tool("echo", %{"message" => message}, _state) do
    # M3 Sprint 3: Enable screenshot testing via echo tool
    # If message contains "screenshot", set flag to trigger capture on next turn
    lens_updates =
      if String.contains?(String.downcase(message), "screenshot") do
        [request_screenshot: true]
      else
        []
      end

    # Return message with optional lens_updates
    if lens_updates == [] do
      {:ok, message}
    else
      {:ok, message, lens_updates}
    end
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
