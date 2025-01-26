defmodule NineMensMorris.Game do
  use GenServer

  alias NineMensMorris.Board
  alias NineMensMorris.BoardCoordinates

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
       board: Board.new(),
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

  def remove_piece(game_id, position, player) do
    GenServer.call(via_tuple(game_id), {:remove_piece, position, player})
  end

  def start_or_get(game_id) do
    case Registry.lookup(NineMensMorris.GameRegistry, game_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> DynamicSupervisor.start_child(NineMensMorris.GameSupervisor, {__MODULE__, game_id})
    end
  end

  def handle_call(:current_player, _from, state) do
    {:reply, state.current_player, state}
  end

  def handle_call(:awaiting_player?, _from, state) do
    state = process_pending_downs(state)
    {:reply, map_size(state.players) < 2, state}
  end

  def handle_call(:game_full?, _from, state) do
    state = process_pending_downs(state)
    {:reply, map_size(state.players) >= 2, state}
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

  def handle_call({:place_piece, position, player}, _from, state) do
    case Board.place_piece(state.board, position, player) do
      {:ok, new_board} ->
        coordinates = BoardCoordinates.get_coordinates(position)

        broadcast(
          state.game_id,
          {:piece_placed,
           %{
             position: position,
             player: player,
             current_player: next_player(player),
             coordinates: coordinates
           }}
        )

        formed_mills =
          Enum.filter(new_board.mills, fn mill ->
            Board.is_mill?(new_board, mill) and
              Enum.all?(mill, fn pos -> new_board.positions[pos] == player end)
          end)

        new_state = %{
          state
          | board: new_board,
            current_player: next_player(player),
            phase: update_game_phase(new_board, state.phase)
        }

        if formed_mills != [] do
          broadcast(state.game_id, {:mill_formed, player, formed_mills})
        end

        {:reply, {:ok, new_board}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:remove_piece, position, player}, _from, state) do
    opponent = next_player(player)

    case state.board.positions[position] do
      ^opponent ->
        case Board.remove_piece(state.board, position, player) do
          {:ok, new_board} ->
            coordinates = BoardCoordinates.get_coordinates(position)

            broadcast(
              state.game_id,
              {:piece_removed,
               %{
                 position: position,
                 player: player,
                 current_player: next_player(player),
                 coordinates: coordinates
               }}
            )

            new_state = %{
              state
              | board: new_board,
                current_player: next_player(player),
                captures: Map.update!(state.captures, player, &(&1 + 1))
            }

            {:reply, {:ok, new_board}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      _ ->
        {:reply, {:error, :invalid_piece_removal}, state}
    end
  end

  defp next_player(:white), do: :black
  defp next_player(:black), do: :white

  defp update_game_phase(board, :placement) do
    if board.pieces.white == 0 and board.pieces.black == 0 do
      :move
    else
      :placement
    end
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
