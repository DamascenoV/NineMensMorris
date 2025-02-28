defmodule NineMensMorris.Game.StateTest do
  use ExUnit.Case, async: true
  alias NineMensMorris.Game.State
  alias NineMensMorris.Board

  test "new/1 initializes a new game state" do
    state = State.new("game-1")

    assert state.game_id == "game-1"
    assert state.current_player == :black
    assert state.phase == :placement
    assert state.captures == %{black: 0, white: 0}
    assert state.winner == nil
    assert state.formed_mills == []
    assert state.timeout_ref != nil
  end

  test "update_after_place/5 updates the state after placing a piece" do
    state = State.new("game-1")
    board = Board.new()
    {:ok, new_board} = Board.place_piece(board, :a1, :black)

    updated_state = State.update_after_place(state, new_board, :black, :placement, [])

    assert updated_state.board == new_board
    assert updated_state.current_player == :white
    assert updated_state.phase == :placement
  end

  test "update_after_move/6 updates the state after moving a piece" do
    state = State.new("game-1")
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)
    {:ok, new_board} = Board.move_piece(board, :a1, :a4, :black, :move)

    updated_state = State.update_after_move(state, new_board, :black, :move, [], false)

    assert updated_state.board == new_board
    assert updated_state.current_player == :white
    assert updated_state.phase == :move

    updated_state_mill =
      State.update_after_move(state, new_board, :black, :move, [[:a1, :a4, :a7]], true)

    assert updated_state_mill.current_player == :black
  end

  test "update_after_remove/4 updates the state after removing a piece" do
    state = State.new("game-1")
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :white)
    {:ok, new_board} = Board.remove_piece(board, :a1, :black)

    captures = %{black: 1, white: 0}
    updated_state = State.update_after_remove(state, new_board, :black, captures)

    assert updated_state.board == new_board
    assert updated_state.current_player == :white
    assert updated_state.captures == captures
  end

  test "check_winner/2 detects a winner when opponent has less than 3 pieces" do
    state = State.new("game-1")

    board = %Board{
      positions: %{a1: :white, a4: :white, d1: :black, d2: :black},
      pieces: %{white: 0, black: 0}
    }

    state = %{state | board: board, phase: :move}
    {:ok, board} = Board.remove_piece(board, :d2, :white)
    state = %{state | board: board}

    {updated_state, reason} = State.check_winner(state, :white)

    assert updated_state.winner == :white
    assert reason == :pieces
  end

  test "check_winner/2 detects a winner when opponent is blocked" do
    state = State.new("game-1")
    # Create a board where black is blocked
    positions = Map.new(Board.new().positions, fn {pos, _} -> {pos, :white} end)
    positions = Map.put(positions, :a1, :black)
    positions = Map.put(positions, :a4, :black)
    positions = Map.put(positions, :a7, :black)

    board = %Board{positions: positions, pieces: %{white: 0, black: 0}}
    state = %{state | board: board, phase: :move}

    {updated_state, reason} = State.check_winner(state, :white)

    assert updated_state.winner == :white
    assert reason == :blocked
  end

  test "add_player/2 adds players to the game" do
    state = State.new("game-1")

    {:ok, player_color, updated_state} = State.add_player(state, self())
    assert player_color == :black
    assert map_size(updated_state.players) == 1

    {:ok, player_color, updated_state} = State.add_player(updated_state, spawn(fn -> nil end))
    assert player_color == :white
    assert map_size(updated_state.players) == 2

    {:error, reason, _} = State.add_player(updated_state, spawn(fn -> nil end))
    assert reason == :game_full
  end

  test "remove_player/2 removes a player from the game" do
    state = State.new("game-1")
    pid = self()

    {:ok, _, state_with_player} = State.add_player(state, pid)
    updated_state = State.remove_player(state_with_player, pid)

    assert map_size(updated_state.players) == 0
  end

  test "reset_timeout/1 resets the timeout" do
    state = State.new("game-1")
    old_ref = state.timeout_ref

    updated_state = State.reset_timeout(state)

    refute updated_state.timeout_ref == old_ref
    assert updated_state.timeout_ref != nil
  end

  test "next_player/1 returns the correct next player" do
    assert State.next_player(:black) == :white
    assert State.next_player(:white) == :black
  end
end
