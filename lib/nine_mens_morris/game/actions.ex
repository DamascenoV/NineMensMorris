defmodule NineMensMorris.Game.Actions do
  @moduledoc """
  Provides action handlers for the Nine Men's Morris game.

  This module contains functions that process game actions such as placing,
  moving, and removing pieces. Each function validates the action,
  updates the game state, and returns the result along with any
  game state changes.
  """

  alias NineMensMorris.Board
  alias NineMensMorris.BoardCoordinates
  alias NineMensMorris.Game.{State, Logic, Errors}

  @doc """
  Handles the place piece action.
  """
  @spec place_piece(State.t(), atom(), atom()) ::
          {:ok, State.t(), map()} | {:error, atom(), State.t()}
  def place_piece(state, position, player) do
    cond do
      state.current_player != player ->
        Errors.with_state(:not_your_turn, state)

      BoardCoordinates.get_coordinates(position) == nil ->
        Errors.with_state(:invalid_position, state)

      state.board.positions[position] != nil ->
        Errors.with_state(:position_occupied, state)

      true ->
        place_piece_success(state, position, player)
    end
  end

  defp place_piece_success(state, position, player) do
    case Board.place_piece(state.board, position, player) do
      {:ok, new_board} ->
        coordinates = BoardCoordinates.get_coordinates(position)
        next_player = State.next_player(player)
        new_phase = Logic.update_game_phase(new_board, next_player, state.phase)

        {updated_mills, new_formed_mills, _} =
          Logic.update_mills(state, new_board, player, nil, position)

        new_state =
          State.update_after_place(state, new_board, player, new_phase, updated_mills)

        result = %{
          position: position,
          player: player,
          current_player: next_player,
          phase: new_phase,
          coordinates: coordinates,
          new_mills: new_formed_mills
        }

        {:ok, new_state, result}

      {:error, reason} ->
        Errors.with_state(reason, state)
    end
  end

  @doc """
  Handles the move piece action.
  """
  @spec move_piece(State.t(), atom(), atom(), atom()) ::
          {:ok, State.t(), map(), atom() | nil} | {:error, atom(), State.t()}
  def move_piece(state, from_pos, to_pos, player) do
    case Logic.validate_move(state, from_pos, to_pos, player) do
      :ok ->
        move_piece_success(state, from_pos, to_pos, player)

      {:error, reason} ->
        Errors.with_state(reason, state)
    end
  end

  defp move_piece_success(state, from_pos, to_pos, player) do
    case Board.move_piece(state.board, from_pos, to_pos, player, state.phase) do
      {:ok, new_board} ->
        {updated_mills, new_formed_mills, _} =
          Logic.update_mills(state, new_board, player, from_pos, to_pos)

        formed_new_mill = new_formed_mills != []
        new_phase = Logic.update_game_phase(new_board, State.next_player(player), state.phase)

        new_state =
          State.update_after_move(
            state,
            new_board,
            player,
            new_phase,
            updated_mills,
            formed_new_mill
          )

        {new_state, win_reason} = State.check_winner(new_state, player)

        coordinates_from = BoardCoordinates.get_coordinates(from_pos)
        coordinates_to = BoardCoordinates.get_coordinates(to_pos)

        result = %{
          from: from_pos,
          to: to_pos,
          player: player,
          coordinates_from: coordinates_from,
          coordinates_to: coordinates_to,
          phase: new_state.phase,
          current_player: new_state.current_player,
          new_mills: new_formed_mills
        }

        {:ok, new_state, result, win_reason}

      {:error, reason} ->
        Errors.with_state(reason, state)
    end
  end

  @doc """
  Handles the remove piece action.
  """
  @spec remove_piece(State.t(), atom(), atom()) ::
          {:ok, State.t(), map(), atom() | nil} | {:error, atom(), State.t()}
  def remove_piece(state, position, player) do
    opponent = State.next_player(player)

    if state.board.positions[position] != opponent do
      Errors.with_state(:invalid_piece_removal, state)
    else
      remove_piece_success(state, position, player, opponent)
    end
  end

  defp remove_piece_success(state, position, player, opponent) do
    case Board.remove_piece(state.board, position, player) do
      {:ok, new_board} ->
        coordinates = BoardCoordinates.get_coordinates(position)
        captures = Map.update!(state.captures, player, &(&1 + 1))

        next_player = State.next_player(player)
        new_phase = Logic.update_game_phase(new_board, opponent, state.phase)

        new_state = State.update_after_remove(state, new_board, player, captures, new_phase)
        {new_state, win_reason} = State.check_winner(new_state, player)

        result = %{
          position: position,
          player: player,
          current_player: next_player,
          phase: new_phase,
          coordinates: coordinates,
          captures: captures
        }

        {:ok, new_state, result, win_reason}

      {:error, reason} ->
        Errors.with_state(reason, state)
    end
  end
end
