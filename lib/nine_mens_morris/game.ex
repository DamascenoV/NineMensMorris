defmodule NineMensMorris.Game do
  use GenServer

  alias NineMensMorris.Board
  alias NineMensMorris.BoardCoordinates

  @type t :: %__MODULE__{
          game_id: term(),
          board: Board.t(),
          players: map(),
          current_player: :black | :white | nil,
          phase: :placement | :move | :flying,
          captures: map(),
          winner: atom() | nil,
          formed_mills: list()
        }

  defstruct game_id: nil,
            board: %Board{},
            players: %{},
            current_player: nil,
            phase: :placement,
            captures: %{black: 0, white: 0},
            winner: nil,
            formed_mills: []

  @spec init(String.t()) :: {:ok, t()}
  def init(game_id) do
    set_timeout()

    {:ok,
     %__MODULE__{
       game_id: game_id,
       board: Board.new(),
       players: %{},
       current_player: :black,
       phase: :placement,
       captures: %{black: 0, white: 0},
       winner: nil,
       formed_mills: []
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
    set_timeout()

    case Board.place_piece(state.board, position, player) do
      {:ok, new_board} ->
        coordinates = BoardCoordinates.get_coordinates(position)

        new_phase = update_game_phase(new_board, player, state.phase)

        broadcast(
          state.game_id,
          {:piece_placed,
           %{
             position: position,
             player: player,
             current_player: next_player(player),
             phase: new_phase,
             coordinates: coordinates
           }}
        )

        formed_mills =
          Enum.filter(new_board.mills, fn mill ->
            Board.is_mill?(new_board, mill, player) and
              !Enum.member?(state.formed_mills, mill)
          end)

        new_state = %{
          state
          | board: new_board,
            current_player: next_player(player),
            phase: new_phase,
            formed_mills: state.formed_mills ++ formed_mills
        }

        dbg(new_state)

        if formed_mills != [] do
          broadcast(state.game_id, {:mill_formed, player, formed_mills})
        end

        {:reply, {:ok, new_board}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:move_piece, from_pos, to_pos, player}, _from, state) do
    set_timeout()

    case validate_move(state, from_pos, to_pos, player) do
      :ok ->
        case Board.move_piece(state.board, from_pos, to_pos, player, state.phase) do
          {:ok, new_board} ->
            formed_mills = check_new_mills(new_board, player, state.formed_mills)
            new_state = update_state_after_move(state, new_board, formed_mills, player)

            coordinates_from = BoardCoordinates.get_coordinates(from_pos)
            coordinates_to = BoardCoordinates.get_coordinates(to_pos)

            broadcast(
              state.game_id,
              {:piece_moved,
               %{
                 from: from_pos,
                 to: to_pos,
                 player: player,
                 coordinates_from: coordinates_from,
                 coordinates_to: coordinates_to,
                 phase: new_state.phase,
                 current_player: new_state.current_player
               }}
            )

            if formed_mills != [] do
              broadcast(state.game_id, {:mill_formed, player, formed_mills})
            end

            {:reply, {:ok, new_board}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

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
            captures = Map.update!(state.captures, player, &(&1 + 1))

            broadcast(
              state.game_id,
              {:piece_removed,
               %{
                 position: position,
                 player: player,
                 current_player: next_player(player),
                 coordinates: coordinates,
                 captures: captures
               }}
            )

            new_state = %{
              state
              | board: new_board,
                current_player: next_player(player),
                captures: captures
            }

            opponent_pieces = Board.count_pieces(new_board, opponent)

            if opponent_pieces < 3 do
              %{new_state | winner: player}
            end

            {:reply, {:ok, new_board}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      _ ->
        {:reply, {:error, :invalid_piece_removal}, state}
    end
  end

  def handle_info(:timeout, state) do
    broadcast(state.game_id, {:game_ended, :timeout})
    {:stop, :normal, state}
  end

  def handle_info({:DOWN, _ref, :process, player_pid, _reason}, state) do
    new_players = Map.delete(state.players, player_pid)
    broadcast(state.game_id, {:player_left, player_pid})
    {:noreply, %{state | players: new_players}}
  end

  defp next_player(:white), do: :black
  defp next_player(:black), do: :white

  defp update_game_phase(board, player, current_phase) do
    cond do
      current_phase == :placement && board.pieces.white == 0 && board.pieces.black == 0 ->
        :move

      current_phase == :move && Board.count_pieces(board, player) <= 3 ->
        :flying

      true ->
        current_phase
    end
  end

  defp broadcast(game_id, message) do
    Phoenix.PubSub.broadcast(NineMensMorris.PubSub, "game:#{game_id}", message)
  end

  defp set_timeout() do
    Process.send_after(self(), :timeout, 30 * 60 * 1000)
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

  defp validate_move(state, from_pos, to_pos, player) do
    cond do
      state.winner != nil ->
        {:error, :game_ended}

      state.current_player != player ->
        {:error, :not_your_turn}

      state.board.positions[from_pos] != player ->
        {:error, :invalid_piece}

      state.board.positions[to_pos] != nil ->
        {:error, :position_occupied}

      state.phase == :move && !BoardCoordinates.adjacent_positions?(from_pos, to_pos) ->
        {:error, :non_adjacent_move}

      true ->
        :ok
    end
  end

  defp check_new_mills(board, player, existing_mills) do
    Enum.filter(board.mills, fn mill ->
      Board.is_mill?(board, mill, player) && !Enum.member?(existing_mills, mill)
    end)
  end

  defp update_state_after_move(state, new_board, formed_mills, player) do
    new_state = %{
      state
      | board: new_board,
        current_player: next_player(player),
        phase: update_game_phase(new_board, player, state.phase),
        formed_mills: state.formed_mills ++ formed_mills
    }

    if formed_mills != [] do
      broadcast(state.game_id, {:mill_formed, player, formed_mills})
      %{new_state | pending_removals: length(formed_mills)}
    else
      new_state
    end
  end
end
