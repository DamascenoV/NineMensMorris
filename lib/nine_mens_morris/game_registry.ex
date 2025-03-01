defmodule NineMensMorris.GameRegistry do
  @moduledoc """
  Registry for Nine Men's Morris game processes.

  This module provides a registry for tracking active game processes,
  allowing them to be found by game ID. It is implemented using Elixir's
  Registry module with unique keys.
  """

  def start_link(_opts) do
    Registry.start_link(keys: :unique, name: __MODULE__, partitions: System.schedulers_online())
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  def via_tuple(game_id) do
    {:via, Registry, {__MODULE__, game_id}}
  end

  def lookup(game_id) do
    Registry.lookup(__MODULE__, game_id)
  end
end
