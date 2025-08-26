defmodule NineMensMorrisWeb.GameLiveHelpers do
  @moduledoc """
  Helper functions for GameLive to improve code organization.
  """

  alias NineMensMorris.BoardCoordinates

  @valid_positions [
    :a1,
    :d1,
    :g1,
    :b2,
    :d2,
    :f2,
    :c3,
    :d3,
    :e3,
    :a4,
    :b4,
    :c4,
    :e4,
    :f4,
    :g4,
    :c5,
    :d5,
    :e5,
    :b6,
    :d6,
    :f6,
    :a7,
    :d7,
    :g7
  ]

  @position_strings Map.new(@valid_positions, fn pos -> {Atom.to_string(pos), pos} end)

  @doc """
  Validates a position string and returns the atom if valid.
  """
  @spec validate_position(String.t()) :: {:ok, atom()} | :error
  def validate_position(position_str) do
    case Map.get(@position_strings, position_str) do
      nil -> :error
      position -> {:ok, position}
    end
  end

  @doc """
  Builds a map of placed pieces from board coordinates to player.
  """
  @spec build_placed_pieces_from_board(map()) :: map()
  def build_placed_pieces_from_board(board) do
    board.positions
    |> Enum.filter(fn {_position, player} -> player != nil end)
    |> Enum.map(fn {position, player} ->
      coordinates = BoardCoordinates.get_coordinates(position)
      {coordinates, player}
    end)
    |> Map.new()
  end

  @doc """
  Returns the CSS class for a player color.
  """
  @spec player_color(atom()) :: String.t()
  def player_color(player) when player in [:white, "white"], do: "white"
  def player_color(player) when player in [:black, "black"], do: "black"

  @doc """
  Returns the next player's turn.
  """
  @spec next_player(atom()) :: atom()
  def next_player(:white), do: :black
  def next_player(:black), do: :white

  @doc """
  Generates a random session ID.
  """
  @spec generate_session_id() :: String.t()
  def generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end
end
