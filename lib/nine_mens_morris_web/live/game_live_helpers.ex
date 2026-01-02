defmodule NineMensMorrisWeb.GameLiveHelpers do
  @moduledoc """
  Helper functions for GameLive to improve code organization.
  """

  alias NineMensMorris.BoardCoordinates
  alias NineMensMorris.Game.Errors

  @position_strings Map.new(BoardCoordinates.all_positions(), fn pos ->
                      {Atom.to_string(pos), pos}
                    end)

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
  Generates a cryptographically secure session ID.
  """
  @spec generate_session_id() :: String.t()
  def generate_session_id do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64()
    |> String.replace(["/", "+"], &if(&1 == "/", do: "_", else: "-"))
  end

  @doc """
  Builds a map of socket assigns that should be updated after a successful action.
  Returns a keyword list of assigns to update.
  """
  @spec build_socket_updates(map(), keyword()) :: keyword()
  def build_socket_updates(game_state, opts \\ []) do
    defaults = [
      update_board: true,
      update_pieces: true,
      reset_selection: false,
      can_capture: false
    ]

    opts = Keyword.merge(defaults, opts)

    updates = [
      current_player: game_state.current_player,
      phase: game_state.phase,
      winner: game_state.winner,
      captures: game_state.captures,
      can_capture: opts[:can_capture]
    ]

    updates =
      if opts[:update_board] do
        [{:board, game_state.board} | updates]
      else
        updates
      end

    updates =
      if opts[:update_pieces] do
        pieces = build_placed_pieces_from_board(game_state.board)
        [{:placed_pieces, pieces} | updates]
      else
        updates
      end

    if opts[:reset_selection] do
      [{:selected_piece, nil} | updates]
    else
      updates
    end
  end

  @doc """
  Returns the appropriate error message for a game action error.
  """
  @spec error_message(atom()) :: String.t()
  def error_message(reason) do
    Errors.to_message(reason)
  end
end
