defmodule KoalemosWeb.ScreenshotTestLiveTest do
  use KoalemosWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Koalemos.Caches.ScreenshotCache

  setup do
    # Clear screenshot cache before each test
    ScreenshotCache.clear_all()
    :ok
  end

  describe "mount" do
    test "mounts successfully and displays page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/test/screenshot")

      assert html =~ "Screenshot Test"
      assert html =~ "M3 Sprint 2: Screenshot Capture Testing"
      assert html =~ "Capture Screenshot"
    end

    test "initializes with default state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/screenshot")

      assert render(view) =~ "Captures:"
      assert render(view) =~ "0"  # Initial capture count
    end
  end

  describe "capture_screenshot event" do
    test "triggers screenshot capture via push_event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/screenshot")

      # Click capture button
      render_click(view, "capture_screenshot")

      # Note: We can't test push_event directly in LiveView tests
      # This just verifies the event handler exists and doesn't crash
      assert render(view) =~ "Screenshot Test"
    end
  end

  describe "screenshot_captured event" do
    test "handles screenshot data and stores in cache", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/screenshot")

      # Get the routine_id from assigns
      routine_id = :sys.get_state(view.pid).socket.assigns.routine_id

      # Simulate screenshot data from JavaScript hook
      fake_screenshot = %{
        "data" => "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
        "format" => "png",
        "width" => 100,
        "height" => 50,
        "timestamp" => System.system_time(:millisecond)
      }

      # Send event to LiveView (simulating pushEvent from hook)
      # Use render_hook to simulate hook event
      render_hook(view, "screenshot_captured", fake_screenshot)

      # Verify screenshot stored in cache
      assert {:ok, stored_data} = ScreenshotCache.get(routine_id)
      assert stored_data == fake_screenshot["data"]

      # Verify UI updated
      html = render(view)
      assert html =~ "Last Screenshot"
      assert html =~ "100x50"  # Dimensions
    end

    test "increments capture count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/screenshot")

      # Get the routine_id
      routine_id = :sys.get_state(view.pid).socket.assigns.routine_id

      # Capture first screenshot
      fake_screenshot_1 = %{
        "data" => "fake_base64_data_1",
        "format" => "png",
        "width" => 100,
        "height" => 50,
        "timestamp" => System.system_time(:millisecond)
      }

      render_hook(view, "screenshot_captured", fake_screenshot_1)

      # Verify count is 1
      html = render(view)
      assert html =~ ~r/Captures:.*1/s

      # Capture second screenshot
      fake_screenshot_2 = %{
        "data" => "fake_base64_data_2",
        "format" => "png",
        "width" => 200,
        "height" => 100,
        "timestamp" => System.system_time(:millisecond)
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
        "data" => String.duplicate("A", 10_000),  # ~10KB of data
        "format" => "png",
        "width" => 800,
        "height" => 600,
        "timestamp" => System.system_time(:millisecond)
      }

      render_hook(view, "screenshot_captured", fake_screenshot)

      html = render(view)
      assert html =~ "800x600"  # Dimensions
      assert html =~ "10 KB"    # Size (rounded)
    end
  end

  describe "screenshot_failed event" do
    test "handles screenshot failure and displays error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/screenshot")

      error_data = %{
        "error" => "Failed to load html2canvas library",
        "timestamp" => System.system_time(:millisecond)
      }

      render_hook(view, "screenshot_failed", error_data)

      html = render(view)
      assert html =~ "Error"
      assert html =~ "Failed to load html2canvas library"
    end

    test "handles unknown errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/screenshot")

      error_data = %{
        "timestamp" => System.system_time(:millisecond)
        # No "error" field
      }

      render_hook(view, "screenshot_failed", error_data)

      html = render(view)
      assert html =~ "Unknown error"
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

      # User clicks capture button (simulated)
      render_click(view, "capture_screenshot")

      # JavaScript captures and sends screenshot (simulated)
      fake_screenshot = %{
        "data" => "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
        "format" => "png",
        "width" => 1,
        "height" => 1,
        "timestamp" => System.system_time(:millisecond)
      }

      render_hook(view, "screenshot_captured", fake_screenshot)

      # Verify results
      html = render(view)
      assert html =~ "1"  # Capture count incremented
      assert html =~ "Last Screenshot"
      assert html =~ "1x1"

      # Verify in cache
      assert {:ok, _data} = ScreenshotCache.get(routine_id)
    end
  end
end
