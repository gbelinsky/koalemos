defmodule KoalemosWeb.RoutineChatLiveTest do
  use KoalemosWeb.ConnCase

  test "renders chat page with routine_id", %{conn: conn} do
    routine_id = "routine-123456789"
    conn = get(conn, ~p"/chat/#{routine_id}")
    response = html_response(conn, 200)

    assert response =~ "koalemos chat"
    assert response =~ routine_id
    assert response =~ "ready"
  end

  test "displays status badge", %{conn: conn} do
    conn = get(conn, ~p"/chat/routine-test")
    response = html_response(conn, 200)

    assert response =~ "ready"
  end

  test "has back button to home", %{conn: conn} do
    conn = get(conn, ~p"/chat/routine-test")
    response = html_response(conn, 200)

    # Check for back arrow SVG path
    assert response =~ "M10 19l-7-7m0 0l7-7m-7 7h18"
  end

  test "includes ChatPanel component", %{conn: conn} do
    conn = get(conn, ~p"/chat/routine-test")
    response = html_response(conn, 200)

    # ChatPanel should render input area
    assert response =~ "type your message"
  end
end
