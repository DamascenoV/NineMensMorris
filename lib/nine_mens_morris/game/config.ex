defmodule NineMensMorris.Game.Config do
  @moduledoc """
  Configuration constants for the Nine Men's Morris game.

  This module centralizes timeout values and other configurable settings
  to ensure consistency across the game modules.
  """

  @doc """
  Game inactivity timeout in milliseconds (30 minutes).
  After this period of inactivity, the game process terminates.
  """
  @spec game_timeout_ms() :: pos_integer()
  def game_timeout_ms, do: 30 * 60 * 1000

  @doc """
  Player reconnection timeout in milliseconds (30 seconds).
  If a disconnected player doesn't reconnect within this time,
  they forfeit the game.
  """
  @spec player_timeout_ms() :: pos_integer()
  def player_timeout_ms, do: 30 * 1000

  @doc """
  Delay before terminating a completed game in milliseconds (60 seconds).
  This allows clients time to see the final game result.
  """
  @spec game_cleanup_delay_ms() :: pos_integer()
  def game_cleanup_delay_ms, do: 60 * 1000
end
