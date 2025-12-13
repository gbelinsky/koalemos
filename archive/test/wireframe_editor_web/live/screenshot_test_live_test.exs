defmodule WireframeEditorWeb.ScreenshotTestLiveTest do
  use WireframeEditorWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Koalemos.Caches.ScreenshotCache
  alias Koalemos.EngineManager

  setup do
    # Clear screenshot cache before each test
    ScreenshotCache.clear_all()

    # Cleanup: Stop any routines created by this test after test completes
    on_exit(fn ->
      # Get all screenshot-test routines
      screenshot_routines =
        EngineManager.list_routines()
        |> Enum.filter(fn info -> String.starts_with?(info.id, "screenshot-test-") end)

      # Stop each one
      Enum.each(screenshot_routines, fn info ->
        EngineManager.stop_routine(info.id)
      end)

      # Give processes time to terminate
      :timer.sleep(10)
    end)

    :ok
  end

  describe "mount" do
    test "mounts successfully and displays page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/test/screenshot")

      assert html =~ "Screenshot Integration Test"
      assert html =~ "M3 Sprint 3"
    end

    test "initializes with default state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/screenshot")

      assert render(view) =~ "Captures:"
      # Initial capture count
      assert render(view) =~ "0"
    end
  end

  # Note: capture_screenshot button has been removed (M3 Sprint 3 enhancements)
  # Screenshot capture is now triggered via checkbox in user input panel

  describe "screenshot_captured event" do
    test "handles screenshot data and stores in cache", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/screenshot")

      # Get the routine_id from assigns
      routine_id = :sys.get_state(view.pid).socket.assigns.routine_id

      # Simulate screenshot data from JavaScript hook
      fake_screenshot = %{
        "data" =>
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
        "width" => 100,
        "height" => 50
      }

      # Send event to LiveView (simulating pushEvent from hook)
      render_hook(view, "screenshot_captured", fake_screenshot)

      # Verify screenshot stored in cache
      assert {:ok, stored_data} = ScreenshotCache.get(routine_id)
      assert stored_data == fake_screenshot["data"]

      # Verify capture count incremented
      html = render(view)
      assert html =~ ~r/Captures:.*1/s
      # Dimensions in last screenshot info
      assert html =~ "100x50"
    end

    test "increments capture count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/screenshot")

      # Get the routine_id
      routine_id = :sys.get_state(view.pid).socket.assigns.routine_id

      # Capture first screenshot
      fake_screenshot_1 = %{
        "data" => "fake_base64_data_1",
        "width" => 100,
        "height" => 50
      }

      render_hook(view, "screenshot_captured", fake_screenshot_1)

      # Verify count is 1
      html = render(view)
      assert html =~ ~r/Captures:.*1/s

      # Capture second screenshot
      fake_screenshot_2 = %{
        "data" => "fake_base64_data_2",
        "width" => 200,
        "height" => 100
      }

      render_hook(view, "screenshot_captured", fake_screenshot_2)

      # Verify count is 2
      html = render(view)
      assert html =~ ~r/Captures:.*2/s

      # Verify latest screenshot is in cache
      assert {:ok, stored_data} = ScreenshotCache.get(routine_id)
      assert stored_data == "fake_base64_data_2"
    end

    test "displays screenshot metadata", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/screenshot")

      fake_screenshot = %{
        # ~10KB of data
        "data" => String.duplicate("A", 10_000),
        "width" => 800,
        "height" => 600
      }

      render_hook(view, "screenshot_captured", fake_screenshot)

      html = render(view)
      # Dimensions
      assert html =~ "800x600"
      # Size (rounded)
      assert html =~ "10 KB"
    end
  end

  describe "screenshot_failed event" do
    test "handles screenshot failure gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/screenshot")

      error_data = %{
        "error" => "Failed to load html2canvas library"
      }

      # Should not crash when receiving error
      render_hook(view, "screenshot_failed", error_data)
      assert render(view) =~ "Screenshot Integration Test"
    end

    test "handles unknown errors gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/screenshot")

      # No "error" field
      error_data = %{}

      # Should not crash
      render_hook(view, "screenshot_failed", error_data)
      assert render(view) =~ "Screenshot Integration Test"
    end
  end

  describe "integration" do
    test "full workflow simulation", %{conn: conn} do
      {:ok, view, html} = live(conn, "/test/screenshot")

      # Initial state
      assert html =~ "Captures:"
      assert html =~ "0"

      # Get routine_id
      routine_id = :sys.get_state(view.pid).socket.assigns.routine_id

      # JavaScript captures and sends screenshot (simulated by render_hook)
      fake_screenshot = %{
        "data" =>
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
        "width" => 1,
        "height" => 1
      }

      render_hook(view, "screenshot_captured", fake_screenshot)

      # Verify results
      html = render(view)
      # Capture count incremented
      assert html =~ ~r/Captures:.*1/s
      # Dimensions displayed
      assert html =~ "1x1"

      # Verify in cache
      assert {:ok, _data} = ScreenshotCache.get(routine_id)
    end
  end
end
