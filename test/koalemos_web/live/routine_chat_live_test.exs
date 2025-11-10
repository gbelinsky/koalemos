defmodule KoalemosWeb.RoutineChatLiveTest do
  use KoalemosWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Koalemos.EngineManager

  setup do
    # Cleanup: Stop any routines created by this test after test completes
    on_exit(fn ->
      # Get all routine-test routines
      routine_routines =
        EngineManager.list_routines()
        |> Enum.filter(fn info -> String.starts_with?(info.id, "routine-test-") end)

      # Stop each one
      Enum.each(routine_routines, fn info ->
        EngineManager.stop_routine(info.id)
      end)

      # Give processes time to terminate
      :timer.sleep(10)
    end)

    :ok
  end

  test "renders chat page with routine_id", %{conn: conn} do
    routine_id = "routine-test-#{:erlang.unique_integer([:positive])}"
    {:ok, _view, html} = live(conn, ~p"/chat/#{routine_id}")

    assert html =~ "koalemos chat"
    assert html =~ routine_id
  end

  test "displays running status on mount", %{conn: conn} do
    routine_id = "routine-test-#{:erlang.unique_integer([:positive])}"
    {:ok, _view, html} = live(conn, ~p"/chat/#{routine_id}")

    # Status should be "running" after mount
    assert html =~ "running"
  end

  test "has back button to home", %{conn: conn} do
    routine_id = "routine-test-#{:erlang.unique_integer([:positive])}"
    {:ok, _view, html} = live(conn, ~p"/chat/#{routine_id}")

    # Check for back arrow SVG path
    assert html =~ "M10 19l-7-7m0 0l7-7m-7 7h18"
  end

  test "includes ChatPanel component", %{conn: conn} do
    routine_id = "routine-test-#{:erlang.unique_integer([:positive])}"
    {:ok, _view, html} = live(conn, ~p"/chat/#{routine_id}")

    # ChatPanel should render input area
    assert html =~ "type your message"
  end

  test "starts routine on mount", %{conn: conn} do
    routine_id = "routine-test-#{:erlang.unique_integer([:positive])}"
    {:ok, _view, _html} = live(conn, ~p"/chat/#{routine_id}")

    # Give the routine a moment to start
    Process.sleep(100)

    # Verify routine is running by checking if it's registered
    case Registry.lookup(Koalemos.RoutineRegistry, routine_id) do
      [{pid, _}] ->
        assert Process.alive?(pid)
      [] ->
        flunk("Routine was not started")
    end
  end
end
