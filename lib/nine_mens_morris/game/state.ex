defmodule NineMensMorris.Game.State do
  alias NineMensMorris.Board

  @type t :: %__MODULE__{
          game_id: term(),
          board: Board.t(),
          players: map(),
          current_player: :black | :white | nil,
          phase: :placement | :move | :flying,
          captures: map(),
          winner: atom() | nil,
          formed_mills: list(),
          timeout_ref: reference(),
          last_activity: integer()
        }

  defstruct game_id: nil,
            board: %Board{},
            players: %{},
            current_player: nil,
            phase: :placement,
            captures: %{black: 0, white: 0},
            winner: nil,
            formed_mills: [],
            timeout_ref: nil,
            last_activity: 0

  @doc """
  Creates a new game state with the given game_id.
  """
  @spec new(String.t()) :: t()
  def new(game_id) do
    timeout_ref = Process.send_after(self(), :timeout, 30 * 60 * 1000)

    %__MODULE__{
      game_id: game_id,
      board: Board.new(),
      players: %{},
      current_player: :black,
      phase: :placement,
      captures: %{black: 0, white: 0},
      winner: nil,
      formed_mills: [],
      timeout_ref: timeout_ref,
      last_activity: System.monotonic_time(:second)
    }
  end

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
  Adds a player to the game.
  """
  @spec add_player(t(), pid()) :: {:ok, atom(), t()} | {:error, atom(), t()}
  def add_player(state, player_pid) do
    case map_size(state.players) do
      0 ->
        Process.monitor(player_pid)
        {:ok, :black, %{state | players: Map.put(state.players, player_pid, :black)}}

      1 ->
        Process.monitor(player_pid)
        {:ok, :white, %{state | players: Map.put(state.players, player_pid, :white)}}

      _ ->
        {:error, :game_full, state}
    end
  end

  @doc """
  Removes a player from the game.
  """
  @spec remove_player(t(), pid()) :: t()
  def remove_player(state, player_pid) do
    %{state | players: Map.delete(state.players, player_pid)}
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
