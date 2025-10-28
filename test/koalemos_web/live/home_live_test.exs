defmodule KoalemosWeb.HomeLiveTest do
  use KoalemosWeb.ConnCase

  test "renders landing page", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "koalemos"
    assert response =~ "your ai conversation companion"
    assert response =~ "start chat session"
  end

  test "displays start button", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "start chat session"
  end

  test "has link to samples page", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "view component samples"
    assert response =~ "/samples"
  end
end
