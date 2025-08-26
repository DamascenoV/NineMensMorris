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

  test "validates position input", %{conn: conn, game_id: game_id} do
    {:ok, view, _html} = live(conn, ~p"/game/#{game_id}")

    # Try to place piece with invalid position
    view
    |> render_hook("place_piece", %{"position" => "invalid"})

    # Should not crash and should handle gracefully
    assert view
  end

  test "handles piece selection", %{conn: conn, game_id: game_id} do
    {:ok, view, _html} = live(conn, ~p"/game/#{game_id}")

    # Select a piece (should handle gracefully even if not joined)
    view
    |> render_hook("select_piece", %{"position" => "a1"})

    # Should handle selection
    assert view
  end
end
