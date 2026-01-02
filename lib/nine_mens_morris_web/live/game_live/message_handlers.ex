defmodule NineMensMorrisWeb.GameLive.MessageHandlers do
  @moduledoc """
  Handles PubSub messages for the GameLive module.

  This module processes game state updates received via PubSub broadcasts
  and returns the updated socket assigns.
  """

  alias NineMensMorris.Game.State
  alias Phoenix.LiveView.Socket

  @doc """
  Handles the player_joined message.
  """
  @spec handle_player_joined(Socket.t(), pid()) :: Socket.t()
  def handle_player_joined(socket, _player_pid) do
    socket
    |> Phoenix.Component.assign(:awaiting_player, false)
    |> Phoenix.Component.assign(
      :current_player,
      NineMensMorris.Game.current_player(socket.assigns.game_id)
    )
  end

  @doc """
  Handles the piece_placed message.
  """
  @spec handle_piece_placed(Socket.t(), map()) :: Socket.t()
  def handle_piece_placed(socket, %{
        position: position,
        player: player,
        current_player: current_player,
        phase: phase,
        coordinates: coordinates
      }) do
    socket
    |> Phoenix.Component.assign(
      :board,
      %{
        socket.assigns.board
        | positions: Map.put(socket.assigns.board.positions, position, player)
      }
    )
    |> Phoenix.Component.assign(:current_player, current_player)
    |> Phoenix.Component.assign(:phase, phase)
    |> Phoenix.Component.update(:placed_pieces, fn pieces ->
      Map.put(pieces, coordinates, player)
    end)
  end

  @doc """
  Handles the piece_moved message.
  """
  @spec handle_piece_moved(Socket.t(), map()) :: Socket.t()
  def handle_piece_moved(socket, %{
        from: from_pos,
        to: to_pos,
        player: player,
        coordinates_from: coordinates_from,
        coordinates_to: coordinates_to,
        phase: phase
      }) do
    socket
    |> Phoenix.Component.assign(
      :board,
      %{
        socket.assigns.board
        | positions:
            socket.assigns.board.positions
            |> Map.put(from_pos, nil)
            |> Map.put(to_pos, player)
      }
    )
    |> Phoenix.Component.assign(:current_player, State.next_player(player))
    |> Phoenix.Component.assign(:phase, phase)
    |> Phoenix.Component.update(:placed_pieces, fn pieces ->
      pieces
      |> Map.delete(coordinates_from)
      |> Map.put(coordinates_to, player)
    end)
    |> Phoenix.Component.assign(:selected_piece, nil)
  end

  @doc """
  Handles the mill_formed message.
  """
  @spec handle_mill_formed(Socket.t(), atom(), list()) :: Socket.t()
  def handle_mill_formed(socket, player, mills) do
    socket
    |> Phoenix.Component.assign(:can_capture, true)
    |> Phoenix.Component.assign(:mill_forming_player, player)
    |> Phoenix.Component.assign(:formed_mills, mills)
    |> Phoenix.Component.assign(:current_player, State.next_player(socket.assigns.current_player))
  end

  @doc """
  Handles the piece_removed message.
  """
  @spec handle_piece_removed(Socket.t(), map()) :: Socket.t()
  def handle_piece_removed(socket, %{
        position: position,
        current_player: current_player,
        coordinates: coordinates,
        captures: captures
      }) do
    socket
    |> Phoenix.Component.assign(
      :board,
      %{
        socket.assigns.board
        | positions: Map.delete(socket.assigns.board.positions, position)
      }
    )
    |> Phoenix.Component.assign(:current_player, current_player)
    |> Phoenix.Component.assign(:can_capture, false)
    |> Phoenix.Component.assign(:captures, captures)
    |> Phoenix.Component.update(:placed_pieces, fn pieces ->
      Map.delete(pieces, coordinates)
    end)
  end

  @doc """
  Handles the game_ended victory message.
  """
  @spec handle_game_ended_victory(Socket.t(), atom(), atom()) :: {Socket.t(), String.t()}
  def handle_game_ended_victory(socket, winner, reason) do
    message =
      case reason do
        :opponent_disconnected -> "Opponent didn't return in time. You win!"
        :pieces -> "Game ended - opponent has less than 3 pieces"
        :blocked -> "Game ended - opponent cannot move"
        _ -> "Game ended by #{reason}"
      end

    socket = Phoenix.Component.assign(socket, :winner, winner)
    {socket, message}
  end

  @doc """
  Handles the game_ended player_left message.
  """
  @spec handle_game_ended_player_left(Socket.t()) :: Socket.t()
  def handle_game_ended_player_left(socket) do
    Phoenix.Component.assign(socket, :winner, :game_abandoned)
  end

  @doc """
  Handles the player_left message.
  """
  @spec handle_player_left(Socket.t(), pid()) :: Socket.t()
  def handle_player_left(socket, _pid) do
    socket
  end
end
