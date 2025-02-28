defmodule NineMensMorris.Game do
  use GenServer

  alias NineMensMorris.Game.State
  alias NineMensMorris.Game.Actions

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: via_tuple(game_id))
  end

  def via_tuple(game_id) do
    {:via, Registry, {NineMensMorris.GameRegistry, game_id}}
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

  def place_piece(game_id, position, player) do
    GenServer.call(via_tuple(game_id), {:place_piece, position, player})
  end

  def move_piece(game_id, from_pos, to_pos, player) do
    GenServer.call(via_tuple(game_id), {:move_piece, from_pos, to_pos, player})
  end

  def remove_piece(game_id, position, player) do
    GenServer.call(via_tuple(game_id), {:remove_piece, position, player})
  end

  def start_or_get(game_id) do
    case Registry.lookup(NineMensMorris.GameRegistry, game_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> DynamicSupervisor.start_child(NineMensMorris.GameSupervisor, {__MODULE__, game_id})
    end
  end

  @impl true
  def init(game_id) do
    {:ok, State.new(game_id)}
  end

  @impl true
  def handle_call(:current_player, _from, state) do
    {:reply, state.current_player, state}
  end

  @impl true
  def handle_call(:awaiting_player?, _from, state) do
    state = process_pending_downs(state)
    {:reply, map_size(state.players) < 2, state}
  end

  @impl true
  def handle_call(:game_full?, _from, state) do
    state = process_pending_downs(state)
    {:reply, map_size(state.players) >= 2, state}
  end

  @impl true
  def handle_call({:join, player_pid}, _from, state) do
    state = process_pending_downs(state)

    case State.add_player(state, player_pid) do
      {:ok, player_color, new_state} ->
        if map_size(state.players) == 1 do
          broadcast(state.game_id, {:player_joined, player_pid})
        end

        {:reply, {:ok, player_color}, new_state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:place_piece, position, player}, _from, state) do
    new_state = State.reset_timeout(state)

    case Actions.place_piece(new_state, position, player) do
      {:ok, updated_state, result} ->
        broadcast(state.game_id, {:piece_placed, result})

        if result.new_mills != [] do
          broadcast(state.game_id, {:mill_formed, player, result.new_mills})
        end

        {:reply, {:ok, updated_state.board}, updated_state}

      {:error, reason, _} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:move_piece, from_pos, to_pos, player}, _from, state) do
    new_state = State.reset_timeout(state)

    case Actions.move_piece(new_state, from_pos, to_pos, player) do
      {:ok, updated_state, result, win_reason} ->
        broadcast(state.game_id, {:piece_moved, result})

        if result.new_mills != [] do
          broadcast(state.game_id, {:mill_formed, player, result.new_mills})
        end

        if win_reason do
          broadcast(state.game_id, {:game_ended, :victory, player, win_reason})
        end

        {:reply, {:ok, updated_state.board}, updated_state}

      {:error, reason, _} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:remove_piece, position, player}, _from, state) do
    new_state = State.reset_timeout(state)

    case Actions.remove_piece(new_state, position, player) do
      {:ok, updated_state, result, win_reason} ->
        broadcast(state.game_id, {:piece_removed, result})

        if win_reason do
          broadcast(state.game_id, {:game_ended, :victory, player, win_reason})
        end

        {:reply, {:ok, updated_state.board}, updated_state}

      {:error, reason, _} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_info(:timeout, state) do
    broadcast(state.game_id, {:game_ended, :timeout})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, player_pid, _reason}, state) do
    new_state = State.remove_player(state, player_pid)
    broadcast(state.game_id, {:player_left, player_pid})

    new_state =
      if map_size(new_state.players) < 2 do
        broadcast(state.game_id, {:game_ended, :player_left})
        %{new_state | winner: :game_abandoned}
      else
        new_state
      end

    {:noreply, new_state}
  end

  defp broadcast(game_id, message) do
    Phoenix.PubSub.broadcast(NineMensMorris.PubSub, "game:#{game_id}", message)
  end

  defp process_pending_downs(state) do
    process_next_down(state)
  end

  defp process_next_down(state) do
    receive do
      {:DOWN, _ref, :process, player_pid, _reason} ->
        new_state = State.remove_player(state, player_pid)
        broadcast(state.game_id, {:player_left, player_pid})

        new_state =
          if map_size(new_state.players) < 2 do
            broadcast(state.game_id, {:game_ended, :player_left})
            %{new_state | winner: :game_abandoned}
          else
            new_state
          end

        process_next_down(new_state)
    after
      0 -> state
    end
  end
end
