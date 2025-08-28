defmodule NineMensMorrisWeb.GameLiveHelpersTest do
  use ExUnit.Case, async: true
  alias NineMensMorrisWeb.GameLiveHelpers
  alias NineMensMorris.Board
  alias NineMensMorris.BoardCoordinates

  describe "validate_position/1" do
    test "returns position atom for valid position string" do
      assert {:ok, :a1} = GameLiveHelpers.validate_position("a1")
      assert {:ok, :d2} = GameLiveHelpers.validate_position("d2")
      assert {:ok, :g7} = GameLiveHelpers.validate_position("g7")
    end

    test "returns error for invalid position string" do
      assert :error = GameLiveHelpers.validate_position("invalid")
      assert :error = GameLiveHelpers.validate_position("h1")
      assert :error = GameLiveHelpers.validate_position("a9")
      assert :error = GameLiveHelpers.validate_position("")
    end

    test "returns error for position with wrong case" do
      assert :error = GameLiveHelpers.validate_position("A1")
      assert :error = GameLiveHelpers.validate_position("D4")
    end
  end

  describe "build_placed_pieces_from_board/1" do
    test "returns empty map for empty board" do
      board = Board.new()
      assert GameLiveHelpers.build_placed_pieces_from_board(board) == %{}
    end

    test "returns map with placed pieces" do
      board = Board.new()
      {:ok, board} = Board.place_piece(board, :a1, :white)
      {:ok, board} = Board.place_piece(board, :d4, :black)

      result = GameLiveHelpers.build_placed_pieces_from_board(board)

      a1_coords = BoardCoordinates.get_coordinates(:a1)
      d4_coords = BoardCoordinates.get_coordinates(:d4)

      assert result[a1_coords] == :white
      assert result[d4_coords] == :black
    end

    test "ignores nil positions" do
      board = %Board{
        positions: %{a1: :white, d4: nil, g7: :black}
      }

      result = GameLiveHelpers.build_placed_pieces_from_board(board)

      a1_coords = BoardCoordinates.get_coordinates(:a1)
      g7_coords = BoardCoordinates.get_coordinates(:g7)

      assert result[a1_coords] == :white
      assert result[g7_coords] == :black
      assert map_size(result) == 2
    end
  end

  describe "player_color/1" do
    test "returns correct color for white player" do
      assert GameLiveHelpers.player_color(:white) == "white"
      assert GameLiveHelpers.player_color("white") == "white"
    end

    test "returns correct color for black player" do
      assert GameLiveHelpers.player_color(:black) == "black"
      assert GameLiveHelpers.player_color("black") == "black"
    end
  end

  describe "next_player/1" do
    test "returns black after white" do
      assert GameLiveHelpers.next_player(:white) == :black
    end

    test "returns white after black" do
      assert GameLiveHelpers.next_player(:black) == :white
    end
  end

  describe "generate_session_id/0" do
    test "returns a string" do
      session_id = GameLiveHelpers.generate_session_id()
      assert is_binary(session_id)
    end

    test "returns different values on multiple calls" do
      session_id1 = GameLiveHelpers.generate_session_id()
      session_id2 = GameLiveHelpers.generate_session_id()

      assert session_id1 != session_id2
    end

    test "returns valid base64 string" do
      session_id = GameLiveHelpers.generate_session_id()

      assert {:ok, _} = Base.decode64(session_id)
    end
  end
end
