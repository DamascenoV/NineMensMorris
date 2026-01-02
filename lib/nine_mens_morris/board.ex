defmodule NineMensMorris.Board do
  @moduledoc """
  Represents the Nine Men's Morris game board.

  This module defines the board structure and provides functions
  for manipulating the board state, including:
  - Placing pieces
  - Moving pieces
  - Removing pieces
  - Checking for mills (three pieces in a row)
  - Counting pieces

  The board consists of 24 positions arranged in three concentric squares
  with connecting lines, where pieces can be placed at intersections.
  """

  alias NineMensMorris.BoardCoordinates

  @type t_player :: :white | :black | nil
  @type t_position :: atom()
  @type t :: %__MODULE__{
          positions: map(),
          mills: list(),
          pieces: map()
        }

  defstruct positions: %{},
            mills: [],
            pieces: %{white: 9, black: 9}

  @spec new() :: t()
  def new do
    %__MODULE__{
      positions: initialize_positions(),
      mills: mills_combinations()
    }
  end

  @spec place_piece(t(), t_position(), t_player()) :: {:ok, t()} | {:error, atom()}
  def place_piece(%__MODULE__{} = board, position, player) do
    if board.pieces[player] > 0 do
      {:ok,
       %__MODULE__{
         board
         | positions: Map.put(board.positions, position, player),
           pieces: Map.update!(board.pieces, player, &(&1 - 1))
       }}
    else
      {:error, :no_pieces_available}
    end
  end

  @spec mill?(t(), list(t_position()), t_player()) :: boolean()
  def mill?(board, mill_combination, player) do
    Enum.all?(mill_combination, fn position ->
      board.positions[position] == player
    end)
  end

  @spec remove_piece(t(), t_position(), t_player()) :: {:ok, t()} | {:error, atom()}
  def remove_piece(board, position, player) do
    opponent = if player == :white, do: :black, else: :white

    case board.positions[position] do
      ^opponent ->
        if can_remove_piece?(board, position, opponent) do
          {:ok, %{board | positions: Map.put(board.positions, position, nil)}}
        else
          {:error, :piece_in_mill}
        end

      _ ->
        {:error, :invalid_piece_removal}
    end
  end

  @spec initialize_positions() :: map()
  defp initialize_positions do
    %{
      a1: nil,
      d1: nil,
      g1: nil,
      b2: nil,
      d2: nil,
      f2: nil,
      c3: nil,
      d3: nil,
      e3: nil,
      a4: nil,
      b4: nil,
      c4: nil,
      e4: nil,
      f4: nil,
      g4: nil,
      c5: nil,
      d5: nil,
      e5: nil,
      b6: nil,
      d6: nil,
      f6: nil,
      a7: nil,
      d7: nil,
      g7: nil
    }
  end

  @spec mills_combinations() :: [[t_position()]]
  defp mills_combinations do
    [
      # Horizontal
      [:a1, :d1, :g1],
      [:b2, :d2, :f2],
      [:c3, :d3, :e3],
      [:a4, :b4, :c4],
      [:e4, :f4, :g4],
      [:c5, :d5, :e5],
      [:b6, :d6, :f6],
      [:a7, :d7, :g7],
      # Vertical
      [:a1, :a4, :a7],
      [:b2, :b4, :b6],
      [:c3, :c4, :c5],
      [:d1, :d2, :d3],
      [:d5, :d6, :d7],
      [:e3, :e4, :e5],
      [:f2, :f4, :f6],
      [:g1, :g4, :g7]
    ]
  end

  @spec can_remove_piece?(t(), t_position(), t_player()) :: boolean()
  defp can_remove_piece?(board, position, player) do
    !in_any_mill?(board, position, player) || all_opponent_pieces_in_mills?(board, player)
  end

  @spec in_any_mill?(t(), t_position(), t_player()) :: boolean()
  defp in_any_mill?(board, position, player) do
    Enum.any?(board.mills, fn mill ->
      Enum.member?(mill, position) &&
        Enum.all?(mill, fn pos -> board.positions[pos] == player end)
    end)
  end

  @spec all_opponent_pieces_in_mills?(t(), t_player()) :: boolean()
  defp all_opponent_pieces_in_mills?(board, player) do
    board.positions
    |> Enum.filter(fn {_, piece_owner} -> piece_owner == player end)
    |> Enum.all?(fn {pos, _} -> in_any_mill?(board, pos, player) end)
  end

  @spec count_pieces(t(), t_player()) :: non_neg_integer()
  def count_pieces(board, player) do
    board.positions
    |> Map.values()
    |> Enum.count(&(&1 == player))
  end

  @spec move_piece(t(), t_position(), t_position(), t_player(), atom()) ::
          {:ok, t()} | {:error, atom()}
  def move_piece(%__MODULE__{} = board, from_pos, to_pos, player, phase) do
    cond do
      board.positions[from_pos] != player ->
        {:error, :invalid_piece}

      board.positions[to_pos] != nil ->
        {:error, :position_occupied}

      not BoardCoordinates.valid_move?(from_pos, to_pos, phase) ->
        {:error, :invalid_move}

      true ->
        new_positions =
          board.positions
          |> Map.put(from_pos, nil)
          |> Map.put(to_pos, player)

        {:ok, %{board | positions: new_positions}}
    end
  end
end
