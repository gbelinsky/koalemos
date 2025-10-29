defmodule KoalemosWeb.HomePageTest do
  use KoalemosWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "koalemos"
    assert html_response(conn, 200) =~ "start chat session"
  end
end
