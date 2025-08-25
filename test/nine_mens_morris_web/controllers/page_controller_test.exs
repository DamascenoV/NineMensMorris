defmodule NineMensMorrisWeb.PageControllerTest do
  use NineMensMorrisWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/lobby"
  end
end
