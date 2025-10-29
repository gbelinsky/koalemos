defmodule KoalemosWeb.RoutineChatLiveTest do
  use KoalemosWeb.ConnCase
  import Phoenix.LiveViewTest

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
