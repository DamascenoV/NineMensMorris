defmodule NineMensMorris.Game.Errors do
  @moduledoc """
  Standardized error handling for the Nine Men's Morris game.

  This module defines error types and provides utilities for consistent
  error handling across the game modules.
  """

  @type error_reason ::
          :not_your_turn
          | :invalid_position
          | :position_occupied
          | :invalid_piece
          | :invalid_move
          | :game_ended
          | :invalid_piece_removal
          | :game_full
          | :invalid_password
          | :game_not_found
          | :game_exists

  @type error_tuple :: {:error, error_reason()}
  @type error_tuple_with_state :: {:error, error_reason(), any()}

  @doc """
  Returns a user-friendly error message for a given error reason.
  """
  @spec to_message(error_reason()) :: String.t()
  def to_message(:not_your_turn), do: "It's not your turn"
  def to_message(:invalid_position), do: "Invalid position on the board"
  def to_message(:position_occupied), do: "Position is already occupied"
  def to_message(:invalid_piece), do: "Invalid piece selection"
  def to_message(:invalid_move), do: "Invalid move"
  def to_message(:game_ended), do: "The game has ended"
  def to_message(:invalid_piece_removal), do: "Cannot remove that piece"
  def to_message(:game_full), do: "Game is already full"
  def to_message(:invalid_password), do: "Invalid password"
  def to_message(:game_not_found), do: "Game not found"
  def to_message(:game_exists), do: "Game already exists"

  @doc """
  Checks if an error reason should be logged as a warning.
  """
  @spec should_log?(error_reason()) :: boolean()
  def should_log?(:invalid_password), do: true
  def should_log?(:game_not_found), do: true
  def should_log?(_reason), do: false

  @doc """
  Wraps an error with state for functions that need to return the current state.
  """
  @spec with_state(error_reason(), any()) :: error_tuple_with_state()
  def with_state(reason, state), do: {:error, reason, state}

  @doc """
  Creates a simple error tuple without state.
  """
  @spec simple(error_reason()) :: error_tuple()
  def simple(reason), do: {:error, reason}
end
