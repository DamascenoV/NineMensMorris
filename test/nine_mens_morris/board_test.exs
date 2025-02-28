defmodule NineMensMorris.BoardTest do
  use ExUnit.Case, async: true
  alias NineMensMorris.Board

  test "new/0 initializes an empty board" do
    board = Board.new()
    assert board.pieces.white == 9
    assert board.pieces.black == 9
    assert Enum.all?(Map.values(board.positions), &is_nil/1)
    assert length(board.mills) == 16
  end

  test "place_piece/3 places a piece on the board" do
    board = Board.new()

    {:ok, board} = Board.place_piece(board, :a1, :black)
    assert board.positions[:a1] == :black
    assert board.pieces.black == 8
    assert board.pieces.white == 9

    {:ok, board} = Board.place_piece(board, :d1, :white)
    assert board.positions[:d1] == :white
    assert board.pieces.white == 8
  end

  test "place_piece/3 returns error when no pieces left" do
    board = %{Board.new() | pieces: %{white: 0, black: 0}}

    result = Board.place_piece(board, :a1, :white)
    assert result == {:error, "No more pieces available"}
  end

  test "is_mill?/3 correctly identifies mills" do
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)
    {:ok, board} = Board.place_piece(board, :a4, :black)
    {:ok, board} = Board.place_piece(board, :a7, :black)

    assert Board.is_mill?(board, [:a1, :a4, :a7], :black) == true
    assert Board.is_mill?(board, [:a1, :d1, :g1], :black) == false
  end

  test "remove_piece/3 removes an opponent's piece" do
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :white)

    {:ok, board} = Board.remove_piece(board, :a1, :black)
    assert board.positions[:a1] == nil
  end

  test "remove_piece/3 cannot remove a piece in a mill if other pieces are available" do
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :white)
    {:ok, board} = Board.place_piece(board, :a4, :white)
    {:ok, board} = Board.place_piece(board, :a7, :white)
    {:ok, board} = Board.place_piece(board, :b2, :white)

    result = Board.remove_piece(board, :a1, :black)
    assert result == {:error, "Cannot remove piece in a mill"}

    {:ok, _board} = Board.remove_piece(board, :b2, :black)
  end

  test "count_pieces/2 counts pieces correctly" do
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)
    {:ok, board} = Board.place_piece(board, :d1, :black)
    {:ok, board} = Board.place_piece(board, :g1, :white)

    assert Board.count_pieces(board, :black) == 2
    assert Board.count_pieces(board, :white) == 1
  end

  test "move_piece/5 moves a piece correctly" do
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)

    {:ok, new_board} = Board.move_piece(board, :a1, :a4, :black, :move)
    assert new_board.positions[:a1] == nil
    assert new_board.positions[:a4] == :black
  end

  test "move_piece/5 validates moves based on phase" do
    board = Board.new()
    {:ok, board} = Board.place_piece(board, :a1, :black)

    assert {:error, :invalid_move} = Board.move_piece(board, :a1, :g7, :black, :move)
    assert {:ok, _} = Board.move_piece(board, :a1, :g7, :black, :flying)
  end
end
