defmodule NineMensMorris.BoardCoordinates do
  @moduledoc """
  Manages position coordinates and adjacency for the Nine Men's Morris board.

  This module provides mapping between board positions and their coordinates,
  as well as functions to determine adjacent positions and validate moves.

  It contains:
  - Coordinate mapping for visual representation
  - Adjacent position definitions for move validation
  - Functions to convert between positions and coordinates
  - Logic for determining valid moves based on game phase
  """

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

  @reverse_coordinates Map.new(@board_coordinates, fn {coord, pos} -> {pos, coord} end)

  @all_positions Map.values(@board_coordinates)

  @adjacent_positions %{
    a1: [:a4, :d1],
    a4: [:a1, :a7, :b4],
    a7: [:a4, :d7],
    b2: [:b4, :d2],
    b4: [:b2, :b6, :a4, :c4],
    b6: [:b4, :d6],
    c3: [:c4, :d3],
    c4: [:c3, :c5, :b4],
    c5: [:c4, :d5],
    d1: [:a1, :d2, :g1],
    d2: [:d1, :d3, :b2, :f2],
    d3: [:d2, :c3, :e3],
    d5: [:d6, :c5, :e5],
    d6: [:d5, :d7, :b6, :f6],
    d7: [:d6, :a7, :g7],
    e3: [:e4, :d3],
    e4: [:e3, :e5, :f4],
    e5: [:e4, :d5],
    f2: [:f4, :d2],
    f4: [:f2, :f6, :e4, :g4],
    f6: [:f4, :d6],
    g1: [:g4, :d1],
    g4: [:g1, :g7, :f4],
    g7: [:g4, :d7]
  }

  @spec get_position(number(), number(), number()) :: atom() | nil
  def get_position(x, y, tolerance \\ 10) do
    Enum.find_value(@board_coordinates, fn {{cx, cy}, pos} ->
      if abs(x - cx) <= tolerance and abs(y - cy) <= tolerance do
        pos
      end
    end)
  end

  @spec get_coordinates(atom()) :: {number(), number()} | nil
  def get_coordinates(position) do
    Map.get(@reverse_coordinates, position)
  end

  @spec adjacent_positions?(atom(), atom()) :: boolean()
  def adjacent_positions?(from, to) do
    to in @adjacent_positions[from]
  end

  @spec get_adjacent_positions(atom()) :: [atom()]
  def get_adjacent_positions(position) do
    Map.get(@adjacent_positions, position, [])
  end

  @spec valid_move?(atom(), atom(), atom()) :: boolean()
  def valid_move?(_from_pos, _to_pos, :flying), do: true
  def valid_move?(from_pos, to_pos, :move), do: adjacent_positions?(from_pos, to_pos)
  def valid_move?(_, _, _), do: false

  @doc """
  Returns coordinates in the format expected by LiveView templates.
  """
  @spec coordinates_for_template() :: [{number(), number()}]
  def coordinates_for_template do
    @reverse_coordinates
    |> Map.values()
    |> Enum.sort_by(fn {x, y} -> {y, x} end)
  end

  @doc """
  Validates if a position exists on the board.
  """
  @spec valid_position?(atom()) :: boolean()
  def valid_position?(position) do
    Map.has_key?(@reverse_coordinates, position)
  end

  @doc """
  Returns all valid board positions.
  """
  @spec all_positions() :: [atom()]
  def all_positions do
    @all_positions
  end
end
