defmodule Koalemos.Lenses.ScreenshotIntegrationTest do
  @moduledoc """
  Integration tests for M3 Sprint 3: Screenshot integration via provide_context().

  Tests the full flow:
  1. Tool sets :request_screenshot flag in lens_state
  2. provide_context() checks flag and triggers screenshot capture
  3. Screenshot captured and stored in cache
  4. Screenshot included in context blocks
  """
  use ExUnit.Case, async: false

  alias Koalemos.Lenses.TestLensScreenshot
  alias Koalemos.Caches.ScreenshotCache

  setup do
    # Clear screenshot cache before each test
    ScreenshotCache.clear_all()
    :ok
  end

  describe "provide_context/1 with screenshot flag" do
    test "includes screenshot when :request_screenshot is true and screenshot available" do
      routine_id = "test-routine-#{:erlang.unique_integer([:positive])}"

      # Pre-populate screenshot in cache (simulating successful capture)
      fake_screenshot =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

      :ok = ScreenshotCache.put(routine_id, fake_screenshot)

      # Subscribe to response topic (needed for screenshot capture helper)
      Phoenix.PubSub.subscribe(Koalemos.PubSub, "screenshot:response:#{routine_id}")

      # Simulate screenshot_ready message (this would normally come from LiveView)
      # We'll spawn a process to broadcast it after a short delay
      spawn(fn ->
        Process.sleep(10)

        Phoenix.PubSub.broadcast(
          Koalemos.PubSub,
          "screenshot:response:#{routine_id}",
          {:screenshot_ready, routine_id}
        )
      end)

      # Create state with :request_screenshot flag
      state = %{
        routine_id: routine_id,
        context: %{
          lens_state: %{request_screenshot: true}
        }
      }

      # Call provide_context
      context_blocks = TestLensScreenshot.provide_context(state)

      # Should include base text + screenshot image
      assert length(context_blocks) == 2

      # First block is text context
      assert %{type: "text", text: "Test context from TestLens"} = Enum.at(context_blocks, 0)

      # Second block is screenshot image
      screenshot_block = Enum.at(context_blocks, 1)
      assert %{type: "image"} = screenshot_block
      assert screenshot_block.source.type == "base64"
      assert screenshot_block.source.media_type == "image/png"
      assert screenshot_block.source.data == fake_screenshot
    end

    test "skips screenshot when :request_screenshot is false" do
      routine_id = "test-routine-#{:erlang.unique_integer([:positive])}"

      state = %{
        routine_id: routine_id,
        context: %{
          lens_state: %{request_screenshot: false}
        }
      }

      context_blocks = TestLensScreenshot.provide_context(state)

      # Should only include base text (no screenshot)
      assert length(context_blocks) == 1
      assert %{type: "text", text: "Test context from TestLens"} = Enum.at(context_blocks, 0)
    end

    test "skips screenshot when :request_screenshot is not present" do
      routine_id = "test-routine-#{:erlang.unique_integer([:positive])}"

      state = %{
        routine_id: routine_id,
        context: %{lens_state: %{}}
      }

      context_blocks = TestLensScreenshot.provide_context(state)

      # Should only include base text (no screenshot)
      assert length(context_blocks) == 1
      assert %{type: "text", text: "Test context from TestLens"} = Enum.at(context_blocks, 0)
    end

    test "handles screenshot timeout gracefully" do
      routine_id = "test-routine-timeout-#{:erlang.unique_integer([:positive])}"

      # Don't send screenshot_ready message - will timeout

      state = %{
        routine_id: routine_id,
        context: %{
          lens_state: %{request_screenshot: true}
        }
      }

      # This will timeout after 5 seconds, but we'll let it proceed
      # The test should complete without crashing
      context_blocks = TestLensScreenshot.provide_context(state)

      # Should only include base text (screenshot failed/timed out)
      assert length(context_blocks) == 1
      assert %{type: "text", text: "Test context from TestLens"} = Enum.at(context_blocks, 0)
    end

    test "handles missing routine_id gracefully" do
      state = %{
        context: %{
          lens_state: %{request_screenshot: true}
          # No routine_id
        }
      }

      context_blocks = TestLensScreenshot.provide_context(state)

      # Should only include base text (screenshot failed - no routine_id)
      assert length(context_blocks) == 1
      assert %{type: "text", text: "Test context from TestLens"} = Enum.at(context_blocks, 0)
    end
  end

  describe "echo tool screenshot trigger" do
    test "sets :request_screenshot flag when message contains 'screenshot'" do
      state = %{context: %{}, lens_state: %{}}

      result =
        TestLensScreenshot.execute_tool("echo", %{"message" => "please take a screenshot"}, state)

      # Should return message with lens_updates
      assert {:ok, "please take a screenshot", lens_updates} = result
      assert lens_updates == [request_screenshot: true]
    end

    test "sets :request_screenshot flag when message contains 'Screenshot' (case insensitive)" do
      state = %{context: %{}, lens_state: %{}}

      result =
        TestLensScreenshot.execute_tool("echo", %{"message" => "Take a Screenshot please"}, state)

      assert {:ok, "Take a Screenshot please", lens_updates} = result
      assert lens_updates == [request_screenshot: true]
    end

    test "does not set flag when message does not contain 'screenshot'" do
      state = %{context: %{}, lens_state: %{}}

      result = TestLensScreenshot.execute_tool("echo", %{"message" => "hello world"}, state)

      # Should return simple message without lens_updates
      assert {:ok, "hello world"} = result
    end
  end

  describe "screenshot cache integration" do
    test "retrieve screenshot from cache after storing" do
      routine_id = "cache-test-#{:erlang.unique_integer([:positive])}"
      fake_data = "fake_base64_screenshot_data"

      # Store screenshot
      assert :ok = ScreenshotCache.put(routine_id, fake_data)

      # Retrieve screenshot
      assert {:ok, retrieved_data} = ScreenshotCache.get(routine_id)
      assert retrieved_data == fake_data
    end

    test "returns error when screenshot not in cache" do
      routine_id = "nonexistent-routine"

      assert {:error, :not_found} = ScreenshotCache.get(routine_id)
    end
  end
end
