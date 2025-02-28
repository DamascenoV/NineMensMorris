defmodule NineMensMorris.Game.ActionsTest do
  use ExUnit.Case, async: true
  alias NineMensMorris.Game.Actions
  alias NineMensMorris.Game.State
  alias NineMensMorris.Board

  test "place_piece/3 places a piece and updates game state" do
    state = State.new("game-1")

    {:ok, new_state, result} = Actions.place_piece(state, :a1, :black)

    assert new_state.board.positions[:a1] == :black
    assert new_state.current_player == :white
    assert result.position == :a1
    assert result.player == :black
    assert result.current_player == :white
  end

  test "place_piece/3 handles errors correctly" do
    state = State.new("game-1")

    {:error, reason, _} = Actions.place_piece(state, :a1, :white)
    assert reason == :not_your_turn
  end

  test "place_piece/3 detects formed mills" do
    state = State.new("game-1")

    {:ok, state, _} = Actions.place_piece(state, :a1, :black)
    {:ok, state, _} = Actions.place_piece(state, :b2, :white)
    {:ok, state, _} = Actions.place_piece(state, :a4, :black)
    {:ok, state, _} = Actions.place_piece(state, :b4, :white)

    {:ok, _, result} = Actions.place_piece(state, :a7, :black)

    assert length(result.new_mills) == 1
    assert hd(result.new_mills) == [:a1, :a4, :a7]
  end

  test "move_piece/4 moves a piece and updates game state" do
    state = State.new("game-1")
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)
    state = %{state | board: board, phase: :move}

    {:ok, new_state, result, _} = Actions.move_piece(state, :a1, :a4, :black)

    assert new_state.board.positions[:a1] == nil
    assert new_state.board.positions[:a4] == :black
    assert result.from == :a1
    assert result.to == :a4
    assert result.player == :black
  end

  test "move_piece/4 handles validation errors" do
    state = State.new("game-1")
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)
    state = %{state | board: board, phase: :move}

    {:error, reason, _} = Actions.move_piece(state, :a1, :g7, :black)
    assert reason == :invalid_move

    {:error, reason, _} = Actions.move_piece(state, :a1, :a4, :white)
    assert reason == :not_your_turn
  end

  test "move_piece/4 detects when a mill is formed" do
    state = State.new("game-1")
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)
    {:ok, board} = Board.place_piece(board, :a7, :black)
    {:ok, board} = Board.place_piece(board, :b4, :black)
    state = %{state | board: board, phase: :move}

    {:ok, _, result, _} = Actions.move_piece(state, :b4, :a4, :black)

    assert hd(result.new_mills) == [:a1, :a4, :a7]
  end

  test "remove_piece/3 removes an opponent's piece" do
    state = State.new("game-1")
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :white)
    state = %{state | board: board}

    {:ok, new_state, result, nil} = Actions.remove_piece(state, :a1, :black)

    assert new_state.board.positions[:a1] == nil
    assert new_state.captures.black == 1
    assert result.position == :a1
    assert result.player == :black
    assert result.captures.black == 1
  end

  test "remove_piece/3 handles errors" do
    state = State.new("game-1")

    {:error, reason, _} = Actions.remove_piece(state, :a1, :black)
    assert reason == :invalid_piece_removal

    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)
    state = %{state | board: board}

    {:error, reason, _} = Actions.remove_piece(state, :a1, :black)
    assert reason == :invalid_piece_removal
  end

  test "remove_piece/3 detects win conditions" do
    state = State.new("game-1")

    board = %Board{
      positions: %{
        a1: :black,
        a4: :black,
        a7: :black,
        d1: :white,
        d2: :white,
        d3: :white
      },
      pieces: %{white: 0, black: 0}
    }

    state = %{state | board: board, phase: :move}

    {:ok, final_state, _, win_reason} = Actions.remove_piece(state, :d3, :black)

    assert win_reason == :pieces
    assert final_state.winner == :black
  end
end
