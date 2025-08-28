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
        case Board.place_piece(state.board, position, player) do
          {:ok, new_board} ->
            coordinates = BoardCoordinates.get_coordinates(position)
            new_phase = Logic.update_game_phase(new_board, player, state.phase)

            {updated_mills, new_formed_mills, _} =
              Logic.update_mills(state, new_board, player, nil, position)

            new_state =
              State.update_after_place(state, new_board, player, new_phase, updated_mills)

            result = %{
              position: position,
              player: player,
              current_player: State.next_player(player),
              phase: new_phase,
              coordinates: coordinates,
              new_mills: new_formed_mills
            }

            {:ok, new_state, result}

          {:error, reason} ->
            game_error =
              case reason do
                "No more pieces available" -> :invalid_move
                "Cannot remove piece" -> :invalid_piece_removal
                _ -> :invalid_move
              end

            Errors.with_state(game_error, state)
        end
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
            game_error =
              case reason do
                :invalid_piece -> :invalid_piece
                :position_occupied -> :position_occupied
                :invalid_move -> :invalid_move
                _ -> :invalid_move
              end

            Errors.with_state(game_error, state)
        end

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

    cond do
      state.board.positions[position] != opponent ->
        Errors.with_state(:invalid_piece_removal, state)

      true ->
        case Board.remove_piece(state.board, position, player) do
          {:ok, new_board} ->
            coordinates = BoardCoordinates.get_coordinates(position)
            captures = Map.update!(state.captures, player, &(&1 + 1))

            new_state = State.update_after_remove(state, new_board, player, captures)
            {new_state, win_reason} = State.check_winner(new_state, player)

            result = %{
              position: position,
              player: player,
              current_player: State.next_player(player),
              coordinates: coordinates,
              captures: captures
            }

            {:ok, new_state, result, win_reason}

          {:error, reason} ->
            game_error =
              case reason do
                "Cannot remove piece in a mill" -> :invalid_piece_removal
                "Cannot remove piece" -> :invalid_piece_removal
                _ -> :invalid_move
              end

            Errors.with_state(game_error, state)
        end
    end
  end
end
