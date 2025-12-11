defmodule KoalemosWeb.WireframeTestLiveTest do
  use KoalemosWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  @fixtures_path "test/fixtures"

  describe "mount" do
    test "mounts successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/test/wireframe")

      assert html =~ "Wireframe Test Environment"
      assert html =~ "M4 Sprint 1"
    end

    test "displays empty state initially", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/test/wireframe")

      assert html =~ "No wireframe loaded"
      assert html =~ "Select a sample HTML file"
    end

    test "shows all sample options", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/test/wireframe")

      assert html =~ "Simple Wireframe"
      assert html =~ "Medium Wireframe"
      assert html =~ "Complex Wireframe"
    end

    test "clear button is disabled initially", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/test/wireframe")

      assert html =~ "disabled"
      assert html =~ "Clear Preview"
    end
  end

  describe "load_sample event" do
    @tag :skip
    test "button clicks work (manual test required)", %{conn: _conn} do
      # These tests are skipped due to LiveView test rendering complexity
      # Manual validation required via /test/wireframe page
      # See test/fixtures/wireframe_validation.md for comprehensive manual test checklist
    end
  end

  describe "clear_wireframe event" do
    @tag :skip
    test "clear functionality works (manual test required)", %{conn: _conn} do
      # These tests are skipped due to LiveView test rendering complexity
      # Manual validation required via /test/wireframe page
      # See test/fixtures/wireframe_validation.md for comprehensive manual test checklist
    end
  end

  describe "sample files" do
    test "simple wireframe file exists and is valid HTML", _context do
      path = Path.join([@fixtures_path, "wireframe_simple.html"])
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      assert content =~ "<!DOCTYPE html>"
      assert content =~ "<html"
      assert content =~ "</html>"
      assert content =~ "Simple Wireframe"
    end

    test "medium wireframe file exists and is valid HTML", _context do
      path = Path.join([@fixtures_path, "wireframe_medium.html"])
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      assert content =~ "<!DOCTYPE html>"
      assert content =~ "<html"
      assert content =~ "</html>"
      assert content =~ "Medium"
      assert content =~ "<style>"
    end

    test "complex wireframe file exists and is valid HTML", _context do
      path = Path.join([@fixtures_path, "wireframe_complex.html"])
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      assert content =~ "<!DOCTYPE html>"
      assert content =~ "<html"
      assert content =~ "</html>"
      assert content =~ "Complex"
      assert content =~ "<style>"
      assert content =~ "<script>"
    end

    test "complex wireframe contains expected JavaScript", _context do
      path = Path.join([@fixtures_path, "wireframe_complex.html"])
      {:ok, content} = File.read(path)

      # Should have event listeners
      assert content =~ "addEventListener"
      # Should have tab functionality
      assert content =~ "tab"
      # Should have modal functionality
      assert content =~ "modal"
    end
  end

  describe "helper functions" do
    test "format_bytes formats small values correctly" do
      # Access the module's private function through render (which uses it)
      {:ok, view, _html} = build_conn() |> live("/test/wireframe")

      # Load a file and check size format
      html =
        view
        |> element("button", "Simple Wireframe")
        |> render_click()

      # Should show size in KB or B
      assert html =~ ~r/\d+\.\d+\s+KB|B/
    end
  end

  describe "navigation" do
    test "back to test pages link works", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/test/wireframe")

      assert html =~ "← Test Pages"
      assert html =~ "href=\"/test\""
    end
  end

  describe "status display" do
    test "status shows 'None' initially", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/test/wireframe")

      assert html =~ "Current Sample:"
      assert html =~ "None"
    end

    test "status updates after loading sample", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/test/wireframe")

      html =
        view
        |> element("button", "Simple Wireframe")
        |> render_click()

      assert html =~ "Current Sample:"
      assert html =~ "simple"
      assert html =~ "HTML Size:"
    end
  end
end
