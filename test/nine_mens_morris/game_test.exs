defmodule NineMensMorris.GameTest do
  use ExUnit.Case, async: false
  alias NineMensMorris.Game
  alias NineMensMorris.Game.State

  setup do
    :ok
  end

  describe "game lifecycle" do
    test "start_link/1 starts a game process" do
      assert {:ok, pid} = Game.start_link("test_game_1")
      assert Process.alive?(pid)
    end

    test "start_link/1 with password starts a game process" do
      assert {:ok, pid} = Game.start_link({"test_game_2", "secret"})
      assert Process.alive?(pid)
    end

    test "via_tuple/1 returns correct registry tuple" do
      game_id = "test_game_3"
      expected = {:via, Registry, {NineMensMorris.GameRegistry, game_id}}
      assert Game.via_tuple(game_id) == expected
    end
  end

  describe "player management" do
    setup do
      game_id = "test_player_game"
      {:ok, _pid} = Game.start_link(game_id)
      %{game_id: game_id}
    end

    test "join/2 adds first player as white", %{game_id: game_id} do
      player_pid = self()
      assert {:ok, :white} = Game.join(game_id, player_pid)
      assert Game.current_player(game_id) == :white
    end

    test "join/2 adds second player as black", %{game_id: game_id} do
      player1_pid = spawn(fn -> :timer.sleep(1000) end)
      player2_pid = self()

      {:ok, :white} = Game.join(game_id, player1_pid)
      {:ok, :black} = Game.join(game_id, player2_pid)

      assert Game.current_player(game_id) == :white
    end

    test "join/2 rejects third player", %{game_id: game_id} do
      player1_pid = spawn(fn -> :timer.sleep(1000) end)
      player2_pid = spawn(fn -> :timer.sleep(1000) end)
      player3_pid = self()

      {:ok, :white} = Game.join(game_id, player1_pid)
      {:ok, :black} = Game.join(game_id, player2_pid)
      assert {:error, :game_full} = Game.join(game_id, player3_pid)
    end

    test "awaiting_player?/1 returns true for single player", %{game_id: game_id} do
      player_pid = self()
      {:ok, :white} = Game.join(game_id, player_pid)

      assert Game.awaiting_player?(game_id) == true
    end

    test "awaiting_player?/1 returns false for two players", %{game_id: game_id} do
      player1_pid = spawn(fn -> :timer.sleep(1000) end)
      player2_pid = spawn(fn -> :timer.sleep(1000) end)

      {:ok, :white} = Game.join(game_id, player1_pid)
      {:ok, :black} = Game.join(game_id, player2_pid)

      assert Game.awaiting_player?(game_id) == false
    end

    test "game_full?/1 returns false for single player", %{game_id: game_id} do
      player_pid = self()
      {:ok, :white} = Game.join(game_id, player_pid)

      assert Game.game_full?(game_id) == false
    end

    test "game_full?/1 returns true for two players", %{game_id: game_id} do
      player1_pid = spawn(fn -> :timer.sleep(1000) end)
      player2_pid = spawn(fn -> :timer.sleep(1000) end)

      {:ok, :white} = Game.join(game_id, player1_pid)
      {:ok, :black} = Game.join(game_id, player2_pid)

      assert Game.game_full?(game_id) == true
    end
  end

  describe "password functionality" do
    setup do
      game_id = "test_password_game"
      password = "secret123"
      {:ok, _pid} = Game.start_link({game_id, password})
      %{game_id: game_id, password: password}
    end

    test "join_game/2 with correct password succeeds", %{game_id: game_id, password: password} do
      assert {:ok, _pid} = Game.join_game(game_id, password)
    end

    test "join_game/2 with incorrect password fails", %{game_id: game_id} do
      assert {:error, :invalid_password} = Game.join_game(game_id, "wrong_password")
    end

    test "join_game/2 with no password fails for private game", %{game_id: game_id} do
      assert {:error, :invalid_password} = Game.join_game(game_id, "")
    end

    test "create_game/2 with existing game_id fails", %{game_id: game_id, password: password} do
      assert {:error, :game_exists} = Game.create_game(game_id, password)
    end
  end

  describe "game actions" do
    setup do
      game_id = "test_action_game"
      {:ok, _pid} = Game.start_link(game_id)

      player1_pid = spawn(fn -> :timer.sleep(1000) end)
      player2_pid = spawn(fn -> :timer.sleep(1000) end)
      {:ok, :white} = Game.join(game_id, player1_pid)
      {:ok, :black} = Game.join(game_id, player2_pid)

      %{game_id: game_id, player1_pid: player1_pid, player2_pid: player2_pid}
    end

    test "place_piece/3 places piece correctly", %{game_id: game_id} do
      assert {:ok, board} = Game.place_piece(game_id, :a1, :white)
      assert board.positions[:a1] == :white
    end

    test "place_piece/3 rejects invalid position", %{game_id: game_id} do
      assert {:error, :invalid_position} = Game.place_piece(game_id, :z9, :white)
    end

    test "place_piece/3 rejects occupied position", %{game_id: game_id} do
      {:ok, _board} = Game.place_piece(game_id, :a1, :white)
      {:ok, _board} = Game.place_piece(game_id, :a4, :black)
      assert {:error, :position_occupied} = Game.place_piece(game_id, :a1, :white)
    end

    test "move_piece/4 moves piece correctly", %{game_id: game_id} do
      {:ok, _board} = Game.place_piece(game_id, :a1, :white)

      assert {:error, :not_your_turn} = Game.move_piece(game_id, :a1, :a4, :white)
    end

    test "move_piece/4 rejects invalid move", %{game_id: game_id} do
      {:ok, _board} = Game.place_piece(game_id, :a1, :white)
      assert {:error, :not_your_turn} = Game.move_piece(game_id, :a1, :g7, :white)
    end

    test "remove_piece/3 removes piece correctly", %{game_id: game_id} do
      assert {:error, :invalid_piece_removal} = Game.remove_piece(game_id, :b2, :white)
    end
  end

  describe "game state" do
    setup do
      game_id = "test_state_game"
      {:ok, _pid} = Game.start_link(game_id)
      %{game_id: game_id}
    end

    test "get_game_state/1 returns current state", %{game_id: game_id} do
      state = Game.get_game_state(game_id)
      assert %State{} = state
      assert state.game_id == game_id
      assert state.current_player == nil
      assert state.phase == :placement
    end

    test "current_player/1 returns current player", %{game_id: game_id} do
      assert Game.current_player(game_id) == nil
    end
  end

  describe "game creation and lookup" do
    test "create_game/2 creates a new game" do
      game_id = "new_test_game"
      assert {:ok, pid} = Game.create_game(game_id, nil)
      assert Process.alive?(pid)
    end

    test "join_game/2 finds existing game" do
      game_id = "existing_game"
      {:ok, _pid} = Game.create_game(game_id, nil)

      assert {:ok, pid} = Game.join_game(game_id, "")
      assert Process.alive?(pid)
    end

    test "join_game/2 returns error for non-existent game" do
      assert {:error, :game_not_found} = Game.join_game("non_existent_game", "")
    end

    test "start_or_get/1 returns existing game" do
      game_id = "existing_game_2"
      {:ok, pid1} = Game.create_game(game_id, nil)
      {:ok, pid2} = Game.start_or_get(game_id)

      assert pid1 == pid2
    end
  end
end
