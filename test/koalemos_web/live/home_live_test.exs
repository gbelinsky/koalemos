defmodule KoalemosWeb.HomeLiveTest do
  use KoalemosWeb.ConnCase

  test "renders landing page", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "welcome to koalemos"
    assert response =~ "koalemos is running"
    assert response =~ "a developer framework for building conversational AI applications"
  end

  test "displays start button", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "start chat"
  end

  test "has link to test pages", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "view test pages"
    assert response =~ "/test"
  end
end
