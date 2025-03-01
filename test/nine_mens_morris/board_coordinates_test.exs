defmodule NineMensMorris.BoardCoordinatesTest do
  use ExUnit.Case, async: true
  alias NineMensMorris.BoardCoordinates

  test "get_position returns the correct position for exact coordinates" do
    assert BoardCoordinates.get_position(50, 50) == :a1
    assert BoardCoordinates.get_position(150, 50) == :d1
    assert BoardCoordinates.get_position(125, 175) == :c5
  end

  test "get_position returns the correct position within tolerance" do
    assert BoardCoordinates.get_position(52, 48) == :a1
    assert BoardCoordinates.get_position(145, 53) == :d1
  end

  test "get_position returns nil for coordinates not on the board" do
    assert BoardCoordinates.get_position(1000, 1000) == nil
    assert BoardCoordinates.get_position(30, 30) == nil
  end

  test "get_coordinates returns the correct coordinates for a position" do
    assert BoardCoordinates.get_coordinates(:a1) == {50, 50}
    assert BoardCoordinates.get_coordinates(:d7) == {150, 250}
    assert BoardCoordinates.get_coordinates(:e3) == {175, 125}
  end

  test "adjacent_positions? correctly identifies adjacent positions" do
    assert BoardCoordinates.adjacent_positions?(:a1, :a4) == true
    assert BoardCoordinates.adjacent_positions?(:a1, :d1) == true
    assert BoardCoordinates.adjacent_positions?(:b4, :c4) == true
    assert BoardCoordinates.adjacent_positions?(:a1, :g7) == false
    assert BoardCoordinates.adjacent_positions?(:d1, :d7) == false
  end

  test "get_adjacent_positions returns all adjacent positions" do
    assert BoardCoordinates.get_adjacent_positions(:a1) == [:a4, :d1]
    assert Enum.sort(BoardCoordinates.get_adjacent_positions(:d2)) == [:b2, :d1, :d3, :f2]
    assert Enum.sort(BoardCoordinates.get_adjacent_positions(:b4)) == [:a4, :b2, :b6, :c4]
  end

  test "valid_move? validates moves correctly in different phases" do
    assert BoardCoordinates.valid_move?(:a1, :g7, :flying) == true
    assert BoardCoordinates.valid_move?(:a1, :a4, :move) == true
    assert BoardCoordinates.valid_move?(:a1, :g7, :move) == false
    assert BoardCoordinates.valid_move?(:a1, :a4, :placement) == false
  end
end
