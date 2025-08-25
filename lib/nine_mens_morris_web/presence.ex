defmodule NineMensMorrisWeb.Presence do
  @moduledoc """
  Provides presence tracking for the Nine Men's Morris game.

  This module tracks player presence and cursor positions in real-time.
  """
  use Phoenix.Presence,
    otp_app: :nine_mens_morris,
    pubsub_server: NineMensMorris.PubSub

  @doc """
  Track a player's presence in a game with cursor position.
  """
  def track_cursor(game_id, player_pid, player_color, cursor_x, cursor_y) do
    track(player_pid, "game:#{game_id}", player_color, %{
      cursor_x: cursor_x,
      cursor_y: cursor_y,
      online_at: inspect(System.system_time(:second))
    })
  end

  @doc """
  Update a player's cursor position.
  """
  def update_cursor(game_id, player_pid, player_color, cursor_x, cursor_y) do
    update(player_pid, "game:#{game_id}", player_color, %{
      cursor_x: cursor_x,
      cursor_y: cursor_y,
      online_at: inspect(System.system_time(:second))
    })
  end

  @doc """
  Get presence list for a game.
  """
  def list_game(game_id) do
    list("game:#{game_id}")
  end
end
