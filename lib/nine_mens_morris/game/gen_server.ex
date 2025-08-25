defmodule NineMensMorris.Game do
  @moduledoc """
  GenServer implementation for managing Nine Men's Morris game state.

  This module handles the game lifecycle, player management, and
  action processing. It provides an API for game interactions
  including starting games, joining games, and executing moves.

  The module broadcasts game events to connected clients and manages
  timeouts for inactive games.
  """

  use GenServer

  alias NineMensMorris.Game.State
  alias NineMensMorris.Game.Actions
  alias NineMensMorris.Board

  @spec start_link(String.t() | {String.t(), String.t() | nil}) :: {:ok, pid()} | {:error, any()}
  def start_link(game_id) when is_binary(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: via_tuple(game_id))
  end

  def start_link({game_id, password}) do
    GenServer.start_link(__MODULE__, {game_id, password}, name: via_tuple(game_id))
  end

  @spec via_tuple(String.t()) :: {:via, Registry, {atom(), String.t()}}
  def via_tuple(game_id) do
    {:via, Registry, {NineMensMorris.GameRegistry, game_id}}
  end

  @spec awaiting_player?(String.t()) :: boolean()
  def awaiting_player?(game_id) do
    GenServer.call(via_tuple(game_id), :awaiting_player?)
  end

  @spec join(String.t(), pid()) :: {:ok, atom()} | {:error, atom()}
  def join(game_id, player_pid) do
    GenServer.call(via_tuple(game_id), {:join, player_pid})
  end

  @spec join(String.t(), pid(), String.t() | nil) :: {:ok, atom()} | {:error, atom()}
  def join(game_id, player_pid, session_id) do
    GenServer.call(via_tuple(game_id), {:join, player_pid, session_id})
  end

  @spec create_game(String.t(), String.t()) :: {:ok, pid()} | {:error, atom()}
  def create_game(game_id, password) do
    case start_or_get(game_id, password) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, _pid}} -> {:error, :game_exists}
      {:error, reason} -> {:error, reason}
    end
    |> dbg()
  end

  @spec join_game(String.t(), String.t()) :: {:ok, pid()} | {:error, atom()}
  def join_game(game_id, password) do
    IO.inspect("Game.join_game called with game_id: #{game_id}", label: "GAME_DEBUG")

    case Registry.lookup(NineMensMorris.GameRegistry, game_id) do
      [{pid, _}] ->
        IO.inspect("Game found, attempting to join with password", label: "GAME_DEBUG")
        case GenServer.call(via_tuple(game_id), {:join_with_password, self(), password}) do
          {:ok, player_color} ->
            IO.inspect("Successfully joined game as #{player_color}", label: "GAME_DEBUG")
            {:ok, pid}

          {:error, reason} ->
            IO.inspect("Failed to join game: #{reason}", label: "GAME_DEBUG")
            {:error, reason}
        end

      [] ->
        IO.inspect("Game not found in registry", label: "GAME_DEBUG")
        {:error, :game_not_found}
    end
  end

  @spec join(String.t(), pid(), String.t(), String.t() | nil) :: {:ok, atom()} | {:error, atom()}
  def join(game_id, player_pid, session_id, password) do
    GenServer.call(via_tuple(game_id), {:join_with_password, player_pid, session_id, password})
  end

  @spec game_full?(String.t()) :: boolean()
  def game_full?(game_id) do
    GenServer.call(via_tuple(game_id), :game_full?)
  end

  @spec current_player(String.t()) :: atom()
  def current_player(game_id) do
    GenServer.call(via_tuple(game_id), :current_player)
  end

  @spec get_game_state(String.t()) :: State.t()
  def get_game_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_game_state)
  end

  @spec place_piece(String.t(), atom(), atom()) :: {:ok, Board.t()} | {:error, atom()}
  def place_piece(game_id, position, player) do
    GenServer.call(via_tuple(game_id), {:place_piece, position, player})
  end

  @spec move_piece(String.t(), atom(), atom(), atom()) :: {:ok, Board.t()} | {:error, atom()}
  def move_piece(game_id, from_pos, to_pos, player) do
    GenServer.call(via_tuple(game_id), {:move_piece, from_pos, to_pos, player})
  end

  @spec remove_piece(String.t(), atom(), atom()) :: {:ok, Board.t()} | {:error, atom()}
  def remove_piece(game_id, position, player) do
    GenServer.call(via_tuple(game_id), {:remove_piece, position, player})
  end

  @spec start_or_get(String.t()) :: {:ok, pid()} | {:error, any()}
  @spec start_or_get(String.t(), String.t() | nil) :: {:ok, pid()} | {:error, any()}
  def start_or_get(game_id, password \\ nil) do
    case Registry.lookup(NineMensMorris.GameRegistry, game_id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        if password do
          NineMensMorris.GameSupervisor.start_game(game_id, password)
        else
          NineMensMorris.GameSupervisor.start_game(game_id)
        end
    end
  end

  def init({game_id, password}) do
    IO.inspect("=== GAME INIT START ===", label: "GAME_INIT_DEBUG")
    IO.inspect("Game ID: #{game_id}, Password: #{password}", label: "GAME_INIT_DEBUG")

    try do
      IO.inspect("Creating state...", label: "GAME_INIT_DEBUG")
      state = State.new(game_id, password)
      IO.inspect("State created successfully", label: "GAME_INIT_DEBUG")

      IO.inspect("Setting up timeout...", label: "GAME_INIT_DEBUG")
      timeout_ref = Process.send_after(self(), :timeout, 30 * 60 * 1000)
      state = %{state | timeout_ref: timeout_ref}
      IO.inspect("Timeout set up successfully", label: "GAME_INIT_DEBUG")

      IO.inspect("=== GAME INIT COMPLETE ===", label: "GAME_INIT_DEBUG")
      {:ok, state}
    rescue
      error ->
        IO.inspect("=== GAME INIT ERROR ===", label: "GAME_INIT_DEBUG")
        IO.inspect(error, label: "GAME_INIT_DEBUG")
        {:stop, error}
    end
  end

  def init(game_id) do
    IO.inspect("=== GAME INIT START (no password) ===", label: "GAME_INIT_DEBUG")
    IO.inspect("Game ID: #{game_id}", label: "GAME_INIT_DEBUG")

    try do
      IO.inspect("Creating state...", label: "GAME_INIT_DEBUG")
      state = State.new(game_id)
      IO.inspect("State created successfully", label: "GAME_INIT_DEBUG")

      IO.inspect("Setting up timeout...", label: "GAME_INIT_DEBUG")
      timeout_ref = Process.send_after(self(), :timeout, 30 * 60 * 1000)
      state = %{state | timeout_ref: timeout_ref}
      IO.inspect("Timeout set up successfully", label: "GAME_INIT_DEBUG")

      IO.inspect("=== GAME INIT COMPLETE ===", label: "GAME_INIT_DEBUG")
      {:ok, state}
    rescue
      error ->
        IO.inspect("=== GAME INIT ERROR ===", label: "GAME_INIT_DEBUG")
        IO.inspect(error, label: "GAME_INIT_DEBUG")
        {:stop, error}
    end
  end

  @impl true
  def handle_call(:current_player, _from, state) do
    {:reply, state.current_player, state}
  end

  @impl true
  def handle_call(:get_game_state, _from, state) do
    {:reply, state, state}
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
  def handle_call({:join, player_pid, session_id}, _from, state) do
    state = process_pending_downs(state)

    case State.add_player(state, player_pid, session_id) do
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
  def handle_call({:join, player_pid}, _from, state) do
    state = process_pending_downs(state)

    case State.add_player(state, player_pid, nil) do
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
  def handle_call({:join_with_password, player_pid, password}, _from, state) do
    IO.inspect("handle_call join_with_password called", label: "GAME_DEBUG")
    state = process_pending_downs(state)

    if State.valid_password?(state, password) do
      IO.inspect("Password valid, adding player", label: "GAME_DEBUG")

      case State.add_player(state, player_pid, nil) do
        {:ok, player_color, new_state} ->
          IO.inspect("Player added successfully as #{player_color}", label: "GAME_DEBUG")

          if map_size(state.players) == 1 do
            broadcast(state.game_id, {:player_joined, player_pid})
          end

          {:reply, {:ok, player_color}, new_state}

        {:error, reason, new_state} ->
          IO.inspect("Failed to add player: #{reason}", label: "GAME_DEBUG")
          {:reply, {:error, reason}, new_state}
      end
    else
      IO.inspect("Invalid password", label: "GAME_DEBUG")
      {:reply, {:error, :invalid_password}, state}
    end
  end

  @impl true
  def handle_call({:join_with_password, player_pid, session_id, password}, _from, state) do
    state = process_pending_downs(state)

    if State.valid_password?(state, password) do
      case State.add_player(state, player_pid, session_id) do
        {:ok, player_color, new_state} ->
          if map_size(state.players) == 1 do
            broadcast(state.game_id, {:player_joined, player_pid})
          end

          {:reply, {:ok, player_color}, new_state}

        {:error, reason, new_state} ->
          {:reply, {:error, reason}, new_state}
      end
    else
      {:reply, {:error, :invalid_password}, state}
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
    IO.inspect("Game timeout reached for game: #{state.game_id}", label: "GAME_DEBUG")
    broadcast(state.game_id, {:game_ended, :timeout})
    {:stop, :normal, state}
  end

  @impl true
  def terminate(reason, state) do
    IO.inspect("=== GAME TERMINATING ===", label: "GAME_DEBUG")
    IO.inspect("Game ID: #{state.game_id}", label: "GAME_DEBUG")
    IO.inspect("Reason: #{inspect(reason)}", label: "GAME_DEBUG")
    IO.inspect("State: #{inspect(state, limit: :infinity)}", label: "GAME_DEBUG")
    IO.inspect("=== GAME TERMINATED ===", label: "GAME_DEBUG")
  end

  @impl true
  def handle_info({:player_timeout, session_id}, state) do
    new_state = State.handle_player_timeout(state, session_id)

    if new_state.winner do
      broadcast(state.game_id, {:game_ended, :victory, new_state.winner, :opponent_disconnected})
      {:noreply, new_state}
    else
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, player_pid, _reason}, state) do
    new_state = State.remove_player(state, player_pid)
    broadcast(state.game_id, {:player_left, player_pid})

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
