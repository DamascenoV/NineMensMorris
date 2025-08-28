defmodule NineMensMorrisWeb.RouterTest do
  use NineMensMorrisWeb.ConnCase, async: true

  describe "GET /" do
    test "redirects to lobby", %{conn: conn} do
      conn = get(conn, "/")
      assert redirected_to(conn) == "/lobby"
    end
  end

  describe "GET /lobby" do
    test "renders lobby page", %{conn: conn} do
      conn = get(conn, "/lobby")
      assert html_response(conn, 200) =~ "Nine Men's Morris"
    end
  end

  describe "GET /game/:game_id" do
    test "renders game page for valid game_id", %{conn: conn} do
      game_id = "test_router_game"
      {:ok, _pid} = NineMensMorris.Game.create_game(game_id, nil)

      conn = get(conn, "/game/#{game_id}")
      assert html_response(conn, 200) =~ "Nine Men's Morris"
    end

    test "redirects to lobby for non-existent game", %{conn: conn} do
      conn = get(conn, "/game/non_existent_game")
      assert redirected_to(conn) == "/lobby?error=Game not found"
    end
  end
end
