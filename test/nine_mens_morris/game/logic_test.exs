defmodule NineMensMorris.Game.LogicTest do
  use ExUnit.Case, async: true
  alias NineMensMorris.Game.Logic
  alias NineMensMorris.Board
  alias NineMensMorris.Game.State

  test "update_game_phase/3 transitions from placement to move phase" do
    board = %Board{
      positions: %{a1: :black},
      pieces: %{white: 0, black: 0}
    }

    assert Logic.update_game_phase(board, :black, :placement) == :move
  end

  test "update_game_phase/3 transitions from move to flying phase" do
    board = %Board{
      positions: %{a1: :black, a4: :black, a7: :black},
      pieces: %{white: 0, black: 0}
    }

    assert Logic.update_game_phase(board, :black, :move) == :flying
  end

  test "update_game_phase/3 transitions from flying back to move phase" do
    board = %Board{
      positions: %{a1: :black, a4: :black, a7: :black, d1: :black},
      pieces: %{white: 0, black: 0}
    }

    assert Logic.update_game_phase(board, :black, :flying) == :move
  end

  test "update_mills/5 detects new mills" do
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)
    {:ok, board} = Board.place_piece(board, :a4, :black)

    state = %State{formed_mills: []}

    {updated_mills, new_mills, _} = Logic.update_mills(state, board, :black, nil, :a7)

    assert updated_mills == []
    assert new_mills == []

    {:ok, board} = Board.place_piece(board, :a7, :black)

    {updated_mills, new_mills, _} = Logic.update_mills(state, board, :black, nil, :a7)

    assert length(updated_mills) == 1
    assert length(new_mills) == 1
    assert hd(new_mills) == [:a1, :a4, :a7]
  end

  test "update_mills/5 detects broken mills when moving from a mill" do
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)
    {:ok, board} = Board.place_piece(board, :a4, :black)
    {:ok, board} = Board.place_piece(board, :a7, :black)

    state = %State{formed_mills: [[:a1, :a4, :a7]]}

    {:ok, new_board} = Board.move_piece(board, :a4, :b4, :black, :move)

    {updated_mills, new_mills, broken_mills} =
      Logic.update_mills(state, new_board, :black, :a4, :b4)

    assert updated_mills == []
    assert new_mills == []
    assert broken_mills == [[:a1, :a4, :a7]]
  end

  test "can_player_move?/3 detects when a player can move" do
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)
    {:ok, board} = Board.place_piece(board, :a4, :black)
    {:ok, board} = Board.place_piece(board, :a7, :black)

    assert Logic.can_player_move?(board, :black, :move) == true

    full_board = %Board{
      positions: Map.new(Board.new().positions, fn {pos, _} -> {pos, :white} end)
    }

    full_board = %{full_board | positions: Map.put(full_board.positions, :a1, :black)}

    assert Logic.can_player_move?(full_board, :black, :move) == false
    assert Logic.can_player_move?(full_board, :black, :flying) == false
  end

  test "validate_move/4 validates move correctly" do
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)

    state = %State{
      board: board,
      current_player: :black,
      phase: :move,
      winner: nil
    }

    assert Logic.validate_move(state, :a1, :a4, :black) == :ok
    assert Logic.validate_move(state, :a1, :g7, :black) == {:error, :invalid_move}
    assert Logic.validate_move(state, :a1, :a4, :white) == {:error, :not_your_turn}

    state_with_winner = %{state | winner: :white}
    assert Logic.validate_move(state_with_winner, :a1, :a4, :black) == {:error, :game_ended}
  end
end
