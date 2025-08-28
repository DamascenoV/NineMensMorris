defmodule NineMensMorrisWeb.GameLiveTest do
  use NineMensMorrisWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias NineMensMorris.Game

  setup do
    game_id = "test_game_#{:rand.uniform(1000)}"
    {:ok, _pid} = Game.start_or_get(game_id)
    %{game_id: game_id}
  end

  test "mounts successfully", %{conn: conn, game_id: game_id} do
    {:ok, view, _html} = live(conn, ~p"/game/#{game_id}")

    assert has_element?(view, ".game-title", "Nine Men's Morris")
  end

  test "shows waiting screen when game is not full", %{conn: conn, game_id: game_id} do
    {:ok, view, _html} = live(conn, ~p"/game/#{game_id}")

    assert has_element?(view, ".waiting-screen")
    assert has_element?(view, "p", "Waiting for another player to join")
  end

  test "displays game ID in waiting screen", %{conn: conn, game_id: game_id} do
    {:ok, view, _html} = live(conn, ~p"/game/#{game_id}")

    assert has_element?(view, ".waiting-screen")
    assert has_element?(view, "code", game_id)
    assert has_element?(view, "button", "Copy")
  end

  test "validates position input", %{conn: conn, game_id: game_id} do
    {:ok, view, _html} = live(conn, ~p"/game/#{game_id}")

    view
    |> render_hook("place_piece", %{"position" => "invalid"})

    assert view
  end

  test "handles piece selection", %{conn: conn, game_id: game_id} do
    {:ok, view, _html} = live(conn, ~p"/game/#{game_id}")

    view
    |> render_hook("select_piece", %{"position" => "a1"})

    assert view
  end

  test "redirects to lobby when accessing private game via URL after creator has joined", %{
    conn: _conn
  } do
    private_game_id = "private_game_#{:rand.uniform(1000)}"
    password = "secret123"
    {:ok, _pid} = Game.create_game(private_game_id, password)

    {:ok, _player} = Game.join(private_game_id, self())

    conn2 = Phoenix.ConnTest.build_conn()
    conn2 = Plug.Test.init_test_session(conn2, %{})

    assert {:error,
            {:live_redirect, %{to: "/lobby?error=Private game - please join through the lobby"}}} =
             live(conn2, ~p"/game/#{private_game_id}")
  end

  test "allows creator to access private game via URL before anyone joins", %{conn: conn} do
    private_game_id = "private_game_#{:rand.uniform(1000)}"
    password = "secret123"
    {:ok, _pid} = Game.create_game(private_game_id, password)

    {:ok, _view, _html} = live(conn, ~p"/game/#{private_game_id}")
  end

  test "allows access to public game via URL", %{conn: conn} do
    public_game_id = "public_game_#{:rand.uniform(1000)}"
    {:ok, _pid} = Game.create_game(public_game_id, nil)

    {:ok, view, _html} = live(conn, ~p"/game/#{public_game_id}")

    assert has_element?(view, ".game-title", "Nine Men's Morris")
  end
end
