defmodule NineMensMorris.Game.State do
  @moduledoc """
  Manages the state for Nine Men's Morris game instances.

  This module defines the game state structure and provides functions
  for creating and updating the state based on game actions.

  The state tracks information such as:
  - The game board and its pieces
  - Connected players
  - Current game phase
  - Mills formed on the board
  - Captured pieces
  - Game winner
  - Timeout information
  """

  alias NineMensMorris.Board

  @type t :: %__MODULE__{
          game_id: term(),
          board: Board.t(),
          players: map(),
          player_sessions: map(),
          disconnected_players: map(),
          current_player: :black | :white | nil,
          phase: :placement | :move | :flying,
          captures: map(),
          winner: atom() | nil,
          formed_mills: list(),
          timeout_ref: reference(),
          last_activity: integer(),
          password: String.t() | nil
        }

  defstruct game_id: nil,
            board: %Board{},
            players: %{},
            player_sessions: %{},
            disconnected_players: %{},
            current_player: nil,
            phase: :placement,
            captures: %{black: 0, white: 0},
            winner: nil,
            formed_mills: [],
            timeout_ref: nil,
            last_activity: 0,
            password: nil

  @doc """
  Creates a new game state with the given game_id.
  """
  @spec new(String.t()) :: t()
  def new(game_id) do
    new(game_id, nil)
  end

  @doc """
  Creates a new game state with the given game_id and optional password.
  """
  @spec new(String.t(), String.t() | nil) :: t()
  def new(game_id, password) do
    %__MODULE__{
      game_id: game_id,
      board: Board.new(),
      players: %{},
      player_sessions: %{},
      disconnected_players: %{},
      current_player: nil,
      phase: :placement,
      captures: %{black: 0, white: 0},
      winner: nil,
      formed_mills: [],
      timeout_ref: nil,
      last_activity: System.monotonic_time(:second),
      password: password
    }
  end

  @doc """
  Validates if the provided password matches the game's password.
  Returns true if no password is set or if passwords match.
  """
  @spec valid_password?(t(), String.t() | nil) :: boolean()
  def valid_password?(state, password) do
    cond do
      is_nil(state.password) ->
        true

      is_nil(password) ->
        false

      String.length(password) < 3 ->
        false

      String.length(password) > 50 ->
        false

      true ->
        state.password == password
    end
  end

  @doc """
  Validates password strength for game creation.
  """
  @spec valid_password_for_creation?(String.t() | nil) :: :ok | {:error, String.t()}
  def valid_password_for_creation?(nil), do: :ok

  def valid_password_for_creation?(password) when is_binary(password) do
    cond do
      String.length(password) < 3 ->
        {:error, "Password must be at least 3 characters long"}

      String.length(password) > 50 ->
        {:error, "Password must be no more than 50 characters"}

      String.match?(password, ~r/^[a-zA-Z0-9_-]+$/) == false ->
        {:error, "Password can only contain letters, numbers, underscores, and hyphens"}

      true ->
        :ok
    end
  end

  def valid_password_for_creation?(_), do: {:error, "Invalid password format"}

  @doc """
  Updates the game state after a player places a piece.
  """
  @spec update_after_place(t(), Board.t(), atom(), atom(), list()) :: t()
  def update_after_place(state, new_board, player, new_phase, updated_mills) do
    %{
      state
      | board: new_board,
        current_player: next_player(player),
        phase: new_phase,
        formed_mills: updated_mills,
        last_activity: System.monotonic_time(:second)
    }
  end

  @doc """
  Updates the game state after a player moves a piece.
  """
  @spec update_after_move(t(), Board.t(), atom(), atom(), list(), boolean()) :: t()
  def update_after_move(state, new_board, player, new_phase, updated_mills, formed_new_mill) do
    new_current_player = if formed_new_mill, do: player, else: next_player(player)

    %{
      state
      | board: new_board,
        current_player: new_current_player,
        phase: new_phase,
        formed_mills: updated_mills,
        last_activity: System.monotonic_time(:second)
    }
  end

  @doc """
  Updates the game state after a player removes a piece.
  """
  @spec update_after_remove(t(), Board.t(), atom(), map()) :: t()
  def update_after_remove(state, new_board, player, captures) do
    %{
      state
      | board: new_board,
        current_player: next_player(player),
        captures: captures,
        last_activity: System.monotonic_time(:second)
    }
  end

  @doc """
  Checks if a player has won the game.
  """
  @spec check_winner(t(), atom()) :: {t(), atom() | nil}
  def check_winner(state, player) do
    opponent = next_player(player)
    opponent_pieces = Board.count_pieces(state.board, opponent)

    cond do
      opponent_pieces < 3 && state.phase != :placement ->
        {%{state | winner: player}, :pieces}

      state.phase != :placement &&
          !NineMensMorris.Game.Logic.can_player_move?(state.board, opponent, state.phase) ->
        {%{state | winner: player}, :blocked}

      true ->
        {state, nil}
    end
  end

  @doc """
  Removes a player from the game and tracks them as disconnected.
  """
  @spec remove_player(t(), pid()) :: t()
  def remove_player(state, player_pid) do
    {session_id, player_color} =
      Enum.find_value(state.player_sessions, fn {sid, color} ->
        if Map.get(state.players, player_pid) == color, do: {sid, color}
      end) || {nil, nil}

    new_players = Map.delete(state.players, player_pid)

    new_state = %{state | players: new_players}

    if session_id do
      timeout_ref = Process.send_after(self(), {:player_timeout, session_id}, 3 * 60 * 1000)

      disconnected_player = %{
        color: player_color,
        disconnected_at: System.monotonic_time(:second),
        timeout_ref: timeout_ref
      }

      new_disconnected_players =
        Map.put(state.disconnected_players, session_id, disconnected_player)

      %{new_state | disconnected_players: new_disconnected_players}
    else
      new_state
    end
  end

  @spec add_player(t(), pid(), String.t() | nil) :: {:ok, atom(), t()} | {:error, atom(), t()}
  def add_player(state, player_pid, session_id) do
    existing_player = if session_id, do: find_player_by_session(state, session_id), else: nil

    case existing_player do
      player_color when not is_nil(player_color) ->
        handle_returning_player(state, player_pid, session_id, player_color)

      nil ->
        handle_new_player(state, player_pid, session_id)
    end
  end

  defp handle_returning_player(state, player_pid, session_id, player_color) do
    Process.monitor(player_pid)
    new_players = Map.put(state.players, player_pid, player_color)

    new_sessions =
      if session_id,
        do: Map.put(state.player_sessions, session_id, player_color),
        else: state.player_sessions

    disconnected_players =
      if session_id,
        do: cancel_reconnect_timeout(state.disconnected_players, session_id),
        else: state.disconnected_players

    {:ok, player_color,
     %{
       state
       | players: new_players,
         player_sessions: new_sessions,
         disconnected_players: disconnected_players
     }}
  end

  defp handle_new_player(state, player_pid, session_id) do
    case map_size(state.players) do
      0 ->
        {:ok, player_color, new_state} =
          add_player_with_color(state, player_pid, session_id, :white)

        {:ok, player_color, %{new_state | current_player: :white}}

      1 ->
        add_player_with_color(state, player_pid, session_id, :black)

      _ ->
        {:error, :game_full, state}
    end
  end

  defp add_player_with_color(state, player_pid, session_id, player_color) do
    Process.monitor(player_pid)
    new_players = Map.put(state.players, player_pid, player_color)

    new_sessions =
      if session_id,
        do: Map.put(state.player_sessions, session_id, player_color),
        else: state.player_sessions

    {:ok, player_color, %{state | players: new_players, player_sessions: new_sessions}}
  end

  defp cancel_reconnect_timeout(disconnected_players, session_id) do
    case Map.get(disconnected_players, session_id) do
      %{timeout_ref: timeout_ref} ->
        Process.cancel_timer(timeout_ref)
        Map.delete(disconnected_players, session_id)

      nil ->
        disconnected_players
    end
  end

  @doc """
  Finds a player color by session ID.
  """
  @spec find_player_by_session(t(), String.t()) :: atom() | nil
  def find_player_by_session(state, session_id) do
    Map.get(state.player_sessions, session_id)
  end

  @doc """
  Handles player timeout - ends game and declares winner.
  """
  @spec handle_player_timeout(t(), String.t()) :: t()
  def handle_player_timeout(state, session_id) do
    case Map.get(state.disconnected_players, session_id) do
      %{color: disconnected_color} ->
        winner = if disconnected_color == :black, do: :white, else: :black

        new_disconnected_players = Map.delete(state.disconnected_players, session_id)

        %{state | winner: winner, disconnected_players: new_disconnected_players}

      nil ->
        state
    end
  end

  @doc """
  Updates the timeout for the game.
  """
  @spec reset_timeout(t()) :: t()
  def reset_timeout(state) do
    if state.timeout_ref, do: Process.cancel_timer(state.timeout_ref)
    timeout_ref = Process.send_after(self(), :timeout, 30 * 60 * 1000)
    %{state | timeout_ref: timeout_ref}
  end

  @doc """
  Returns the next player's turn.
  """
  @spec next_player(atom()) :: atom()
  def next_player(:white), do: :black
  def next_player(:black), do: :white
end
