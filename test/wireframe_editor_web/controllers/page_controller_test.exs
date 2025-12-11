defmodule WireframeEditorWeb.HomePageTest do
  use WireframeEditorWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "welcome to koalemos"
    assert html_response(conn, 200) =~ "wireframe editor"
  end
end
