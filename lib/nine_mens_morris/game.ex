defmodule NineMensMorris.Game do
  use GenServer

  @type t :: %__MODULE__{
          game_id: term(),
          board: map(),
          players: map(),
          current_player: :black | :white | nil,
          phase: :placement | :move,
          captures: map(),
          winner: atom() | nil
        }

  defstruct game_id: nil,
            board: %{},
            players: %{},
            current_player: nil,
            phase: :placement,
            captures: %{black: 0, white: 0},
            winner: nil

  def init(game_id) do
    {:ok,
     %__MODULE__{
       game_id: game_id,
       board: NineMensMorris.Board.new(),
       players: %{},
       current_player: :black,
       phase: :placement,
       captures: %{black: 0, white: 0},
       winner: nil
     }}
  end

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: via_tuple(game_id))
  end

  def via_tuple(game_id) do
    {:via, Registry, {NineMensMorris.GameRegistry, game_id}}
  end

  def start_or_get(game_id) do
    case Registry.lookup(NineMensMorris.GameRegistry, game_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> DynamicSupervisor.start_child(NineMensMorris.GameSupervisor, {__MODULE__, game_id})
    end
  end

  def awaiting_player?(game_id) do
    GenServer.call(via_tuple(game_id), :awaiting_player?)
  end

  def join(game_id, player_pid) do
    GenServer.call(via_tuple(game_id), {:join, player_pid})
  end

  def game_full?(game_id) do
    GenServer.call(via_tuple(game_id), :game_full?)
  end

  def current_player(game_id) do
    GenServer.call(via_tuple(game_id), :current_player)
  end

  def handle_call(:current_player, _from, state) do
    {:reply, state.current_player, state}
  end

  def handle_call(:awaiting_player?, _from, state) do
    state = process_pending_downs(state)
    {:reply, map_size(state.players) < 2, state}
  end

  def handle_call({:join, player_pid}, _from, state) do
    state = process_pending_downs(state)

    case map_size(state.players) do
      0 ->
        Process.monitor(player_pid)
        {:reply, {:ok, :black}, %{state | players: Map.put(state.players, player_pid, :black)}}

      1 ->
        Process.monitor(player_pid)
        broadcast(state.game_id, {:player_joined, player_pid})

        {:reply, {:ok, :white},
         %{state | players: Map.put(state.players, player_pid, :white), current_player: :black}}

      _ ->
        {:reply, {:error, :game_full}, state}
    end
  end

  def handle_call(:game_full?, _from, state) do
    state = process_pending_downs(state)
    {:reply, map_size(state.players) > 2, state}
  end

  defp broadcast(game_id, message) do
    Phoenix.PubSub.broadcast(NineMensMorris.PubSub, "game:#{game_id}", message)
  end

  defp process_pending_downs(state) do
    receive do
      {:DOWN, _ref, :process, player_pid, _reason} ->
        new_players = Map.delete(state.players, player_pid)
        broadcast(state.game_id, {:player_left, player_pid})
        process_pending_downs(%{state | players: new_players})
    after
      0 -> state
    end
  end
end
