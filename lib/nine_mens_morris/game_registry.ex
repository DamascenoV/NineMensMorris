defmodule NineMensMorris.GameRegistry do
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
