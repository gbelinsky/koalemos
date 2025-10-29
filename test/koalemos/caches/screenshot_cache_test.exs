defmodule Koalemos.Caches.ScreenshotCacheTest do
  use ExUnit.Case, async: false
  alias Koalemos.Caches.ScreenshotCache

  setup do
    # ScreenshotCache is started by the Application supervision tree
    # We just need to clear it before each test

    # Clear all screenshots before each test
    ScreenshotCache.clear_all()

    # Use unique routine IDs per test to avoid conflicts
    routine_id = "test-routine-#{:erlang.unique_integer([:positive])}"
    {:ok, routine_id: routine_id}
  end

  describe "put/2" do
    test "stores a screenshot successfully", %{routine_id: routine_id} do
      image = "fake_image_data_#{System.unique_integer()}"

      assert :ok = ScreenshotCache.put(routine_id, image)

      # Verify it was stored
      assert {:ok, ^image} = ScreenshotCache.get(routine_id)
    end

    test "overwrites existing screenshot for same routine", %{routine_id: routine_id} do
      first_image = "first_image"
      second_image = "second_image"

      ScreenshotCache.put(routine_id, first_image)
      ScreenshotCache.put(routine_id, second_image)

      # Should have the second image
      assert {:ok, ^second_image} = ScreenshotCache.get(routine_id)
    end

    test "stores screenshots for multiple routines independently" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      image_1 = "image_for_routine_1"
      image_2 = "image_for_routine_2"

      ScreenshotCache.put(routine_1, image_1)
      ScreenshotCache.put(routine_2, image_2)

      assert {:ok, ^image_1} = ScreenshotCache.get(routine_1)
      assert {:ok, ^image_2} = ScreenshotCache.get(routine_2)
    end
  end

  describe "get/1" do
    test "returns {:ok, image} when screenshot exists", %{routine_id: routine_id} do
      image = "test_image_data"
      ScreenshotCache.put(routine_id, image)

      assert {:ok, ^image} = ScreenshotCache.get(routine_id)
    end

    test "returns {:error, :not_found} when screenshot does not exist" do
      nonexistent_id = "nonexistent-routine-#{:erlang.unique_integer([:positive])}"

      assert {:error, :not_found} = ScreenshotCache.get(nonexistent_id)
    end

    test "returns {:error, :not_found} after screenshot is cleared", %{routine_id: routine_id} do
      ScreenshotCache.put(routine_id, "image")
      ScreenshotCache.clear(routine_id)

      assert {:error, :not_found} = ScreenshotCache.get(routine_id)
    end
  end

  describe "clear/1" do
    test "removes screenshot for specified routine", %{routine_id: routine_id} do
      ScreenshotCache.put(routine_id, "image")

      assert :ok = ScreenshotCache.clear(routine_id)
      assert {:error, :not_found} = ScreenshotCache.get(routine_id)
    end

    test "returns :ok even if screenshot does not exist" do
      nonexistent_id = "nonexistent-#{:erlang.unique_integer([:positive])}"

      assert :ok = ScreenshotCache.clear(nonexistent_id)
    end

    test "does not affect other routines' screenshots" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      image_1 = "image_1"
      image_2 = "image_2"

      ScreenshotCache.put(routine_1, image_1)
      ScreenshotCache.put(routine_2, image_2)

      ScreenshotCache.clear(routine_1)

      # routine_2's screenshot should still exist
      assert {:ok, ^image_2} = ScreenshotCache.get(routine_2)
      assert {:error, :not_found} = ScreenshotCache.get(routine_1)
    end
  end

  describe "clear_all/0" do
    test "removes all screenshots" do
      routine_1 = "routine-1-#{:erlang.unique_integer([:positive])}"
      routine_2 = "routine-2-#{:erlang.unique_integer([:positive])}"

      ScreenshotCache.put(routine_1, "image_1")
      ScreenshotCache.put(routine_2, "image_2")

      assert :ok = ScreenshotCache.clear_all()

      assert {:error, :not_found} = ScreenshotCache.get(routine_1)
      assert {:error, :not_found} = ScreenshotCache.get(routine_2)
    end

    test "returns :ok even when cache is empty" do
      ScreenshotCache.clear_all()

      assert :ok = ScreenshotCache.clear_all()
    end
  end

  describe "supervision" do
    test "starts with the application" do
      # The GenServer should be started by setup
      # Verify it's accessible by trying an operation
      routine_id = "supervision-test-#{:erlang.unique_integer([:positive])}"

      assert :ok = ScreenshotCache.put(routine_id, "test")
      assert {:ok, "test"} = ScreenshotCache.get(routine_id)
    end

    test "is registered as a named process" do
      # Should be able to find the process by name
      pid = Process.whereis(ScreenshotCache)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "integration" do
    test "full workflow: put, get, clear" do
      routine_id = "workflow-test-#{:erlang.unique_integer([:positive])}"
      image_data = "base64_encoded_png_data_here"

      # Store screenshot
      assert :ok = ScreenshotCache.put(routine_id, image_data)

      # Retrieve screenshot
      assert {:ok, ^image_data} = ScreenshotCache.get(routine_id)

      # Clear screenshot
      assert :ok = ScreenshotCache.clear(routine_id)

      # Verify cleared
      assert {:error, :not_found} = ScreenshotCache.get(routine_id)
    end

    test "handles large base64 images" do
      routine_id = "large-image-test-#{:erlang.unique_integer([:positive])}"

      # Simulate a reasonably large base64 image (~1MB worth of data)
      large_image = String.duplicate("A", 1_000_000)

      assert :ok = ScreenshotCache.put(routine_id, large_image)
      assert {:ok, ^large_image} = ScreenshotCache.get(routine_id)
    end
  end
end
