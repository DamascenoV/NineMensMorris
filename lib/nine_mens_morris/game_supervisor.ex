defmodule NineMensMorris.GameSupervisor do
  @moduledoc """
  Dynamic supervisor for Nine Men's Morris game processes.

  This module supervises game processes and allows for dynamic creation
  and termination of games. It uses a one-for-one supervision strategy,
  meaning each game process is supervised independently.
  """

  use DynamicSupervisor

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_game(game_id) do
    DynamicSupervisor.start_child(__MODULE__, {NineMensMorris.Game, game_id})
  end

  def start_game(game_id, password) do
    DynamicSupervisor.start_child(__MODULE__, {NineMensMorris.Game, {game_id, password}})
  end
end
