defmodule NineMensMorris.Game.Logic do
  @moduledoc """
  Game logic for the Nine Men's Morris board game.

  This module contains functions that implement the rules of Nine Men's Morris,
  including phase transitions, mill detection, move validation, and
  determining if a player can make valid moves.
  """

  alias NineMensMorris.Board
  alias NineMensMorris.BoardCoordinates
  alias NineMensMorris.Game.State

  @doc """
  Updates the game phase based on the current board state.
  """
  @spec update_game_phase(Board.t(), atom(), atom()) :: atom()
  def update_game_phase(board, player, current_phase) do
    cond do
      current_phase == :placement && board.pieces.white == 0 && board.pieces.black == 0 ->
        :move

      current_phase == :flying && Board.count_pieces(board, player) > 3 ->
        :move

      current_phase == :move && Board.count_pieces(board, player) <= 3 ->
        :flying

      true ->
        current_phase
    end
  end

  @doc """
  Updates the mills in the game state.
  Returns {updated_mills, new_formed_mills, broken_mills}
  """
  @spec update_mills(State.t(), Board.t(), atom(), atom() | nil, atom()) ::
          {list(), list(), list()}
  def update_mills(state, new_board, player, moved_from_pos, moved_to_pos) do
    broken_mills =
      if moved_from_pos != nil do
        Enum.filter(state.formed_mills, fn mill ->
          moved_from_pos in mill and not Board.mill?(new_board, mill, player)
        end)
      else
        []
      end

    new_mills =
      Enum.filter(new_board.mills, fn mill ->
        moved_to_pos in mill and
          Board.mill?(new_board, mill, player) and
          not Enum.member?(state.formed_mills, mill)
      end)

    updated_mills = (state.formed_mills -- broken_mills) ++ new_mills

    {updated_mills, new_mills, broken_mills}
  end

  @doc """
  Checks if a player can make any valid moves.
  """
  @spec can_player_move?(Board.t(), atom(), atom()) :: boolean()
  def can_player_move?(board, player, phase) do
    empty_positions = get_empty_positions(board)

    case phase do
      :flying ->
        not Enum.empty?(empty_positions)

      :move ->
        can_player_move_in_move_phase?(board, player, empty_positions)

      _ ->
        true
    end
  end

  defp get_empty_positions(board) do
    board.positions
    |> Enum.filter(fn {_, piece_owner} -> piece_owner == nil end)
    |> Enum.map(fn {pos, _} -> pos end)
  end

  defp can_player_move_in_move_phase?(board, player, empty_positions) do
    empty_set = MapSet.new(empty_positions)

    board.positions
    |> Enum.filter(fn {_, piece_owner} -> piece_owner == player end)
    |> Enum.any?(fn {pos, _} ->
      adjacent = BoardCoordinates.get_adjacent_positions(pos)
      Enum.any?(adjacent, &MapSet.member?(empty_set, &1))
    end)
  end

  @doc """
  Validates a move.
  """
  @spec validate_move(State.t(), atom(), atom(), atom()) :: :ok | {:error, atom()}
  def validate_move(state, from_pos, to_pos, player) do
    cond do
      state.winner != nil ->
        {:error, :game_ended}

      state.current_player != player ->
        {:error, :not_your_turn}

      state.board.positions[from_pos] != player ->
        {:error, :invalid_piece}

      state.board.positions[to_pos] != nil ->
        {:error, :position_occupied}

      not BoardCoordinates.valid_move?(from_pos, to_pos, state.phase) ->
        {:error, :invalid_move}

      true ->
        :ok
    end
  end
end
