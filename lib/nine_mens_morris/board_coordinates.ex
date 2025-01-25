defmodule NineMensMorris.BoardCoordinates do
  @board_coordinates %{
    {50, 50} => :a1,
    {150, 50} => :d1,
    {250, 50} => :g1,
    {50, 150} => :a4,
    {250, 150} => :g4,
    {50, 250} => :a7,
    {150, 250} => :d7,
    {250, 250} => :g7,
    {87, 87} => :b2,
    {150, 87} => :d2,
    {212, 87} => :f2,
    {87, 150} => :b4,
    {212, 150} => :f4,
    {87, 212} => :b6,
    {150, 212} => :d6,
    {212, 212} => :f6,
    {125, 125} => :c3,
    {150, 125} => :d3,
    {175, 125} => :e3,
    {125, 150} => :c4,
    {175, 150} => :e4,
    {125, 175} => :c5,
    {150, 175} => :d5,
    {175, 175} => :e5
  }

  def get_position(x, y, tolerance \\ 10) do
    Enum.find_value(@board_coordinates, fn {{cx, cy}, pos} ->
      if abs(x - cx) <= tolerance and abs(y - cy) <= tolerance do
        pos
      end
    end)
  end

  def get_coordinates(position) do
    Enum.find_value(@board_coordinates, fn {{x, y}, pos} ->
      if pos == position, do: {x, y}
    end)
  end
end
