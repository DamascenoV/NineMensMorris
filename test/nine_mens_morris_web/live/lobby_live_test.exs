defmodule NineMensMorrisWeb.LobbyLiveTest do
  use NineMensMorrisWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  setup do
    :ok
  end

  describe "mount/3" do
    test "mounts successfully with forms", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      assert has_element?(view, "#join-game-form")
      assert has_element?(view, "#create-game-form")
    end

    test "assigns session_id from session or generates new one", %{conn: conn} do
      conn_with_session =
        conn |> fetch_session() |> put_session("player_session_id", "existing_session")

      {:ok, view, _html} = live(conn_with_session, ~p"/lobby")

      assert has_element?(view, "#join-game-form")

      {:ok, view, _html} = live(conn, ~p"/lobby")
      assert has_element?(view, "#join-game-form")
    end
  end

  describe "join_game event" do
    test "joins existing game successfully", %{conn: conn} do
      game_id = "test_join_game"
      {:ok, _pid} = NineMensMorris.Game.create_game(game_id, nil)

      {:ok, view, _html} = live(conn, ~p"/lobby")

      result =
        view
        |> form("#join-game-form", %{game_id: game_id, password: ""})
        |> render_submit()

      assert {:error, {:live_redirect, %{to: redirect_url}}} = result
      assert String.contains?(redirect_url, "/game/#{game_id}")
    end

    test "shows error for non-existent game", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      view
      |> form("#join-game-form", %{game_id: "non_existent", password: ""})
      |> render_submit()

      assert has_element?(view, ".error-message", "Game not found")
    end

    test "shows error for empty game_id", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      view
      |> form("#join-game-form", %{game_id: "", password: ""})
      |> render_submit()

      assert has_element?(view, ".error-message", "Please enter a game ID")
    end

    test "shows error for invalid password", %{conn: conn} do
      game_id = "private_game"
      password = "secret123"
      {:ok, _pid} = NineMensMorris.Game.create_game(game_id, password)

      {:ok, view, _html} = live(conn, ~p"/lobby")

      view
      |> form("#join-game-form", %{game_id: game_id, password: "wrong_password"})
      |> render_submit()

      assert has_element?(view, ".error-message", "Incorrect password")
    end
  end

  describe "create_game event" do
    test "creates public game successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      result =
        view
        |> form("#create-game-form", %{password: "", is_private: "false"})
        |> render_submit()

      assert {:error, {:live_redirect, %{kind: :push, to: _}}} = result
    end

    test "creates private game successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      result =
        view
        |> form("#create-game-form", %{password: "secret123", is_private: "true"})
        |> render_submit()

      assert {:error, {:live_redirect, %{kind: :push, to: _}}} = result
    end

    test "shows error for private game without password", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      view
      |> form("#create-game-form", %{password: "", is_private: "true"})
      |> render_submit()

      assert has_element?(view, ".error-message", "Private games require a password")
    end
  end

  describe "form validation" do
    test "validate_join updates form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      view
      |> form("#join-game-form", %{game_id: "test_game", password: "test_pass"})
      |> render_change()

      assert has_element?(view, "input[value='test_game']")
      assert has_element?(view, "input[value='test_pass']")
    end

    test "validate_create updates form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      view
      |> form("#create-game-form", %{password: "new_password", is_private: "true"})
      |> render_change()

      assert has_element?(view, "input[value='new_password']")
      assert has_element?(view, "input[checked]")
    end
  end

  describe "error handling" do
    test "clear_error removes error message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/lobby")

      view
      |> form("#join-game-form", %{game_id: "", password: ""})
      |> render_submit()

      assert has_element?(view, ".error-message")

      view
      |> element(".error-close")
      |> render_click()

      refute has_element?(view, ".error-message")
    end

    test "handle_params with error shows error message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/lobby?error=Test Error")

      assert has_element?(view, ".error-message", "Test Error")
    end
  end
end
