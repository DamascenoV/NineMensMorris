defmodule NineMensMorris.Board do
  @type player :: :white | :black
  @type position :: atom()
  @type t :: %__MODULE__{
          positions: map(),
          mills: list(),
          pieces: map()
        }

  defstruct positions: %{},
            mills: [],
            pieces: %{white: 9, black: 9}

  @spec new() :: t()
  def new do
    %__MODULE__{
      positions: initialize_positions(),
      mills: mills_combinations()
    }
  end

  @spec place_piece(t(), position(), player()) :: {:ok, t()} | {:error, String.t()}
  def place_piece(board, position, player) do
    if board.pieces[player] > 0 do
      {:ok,
       %__MODULE__{
         board
         | positions: Map.put(board.positions, position, player),
           pieces: Map.update!(board.pieces, player, &(&1 - 1))
       }}
    else
      {:error, "No more pieces available"}
    end
  end

  @spec is_mill?(t(), [position()]) :: boolean()
  def is_mill?(board, mill_combination) do
    Enum.all?(mill_combination, fn position ->
      board.positions[position] != nil
    end)
  end

  @spec remove_piece(t(), position(), player()) :: {:ok, t()} | {:error, String.t()}
  def remove_piece(board, position, player) do
    opponent = if player == :white, do: :black, else: :white

    case board.positions[position] do
      ^opponent ->
        if can_remove_piece?(board, position, opponent) do
          {:ok, %{board | positions: Map.put(board.positions, position, nil)}}
        else
          {:error, "Cannot remove piece in a mill"}
        end

      _ ->
        {:error, "Cannot remove piece"}
    end
  end

  @spec initialize_positions() :: map()
  defp initialize_positions do
    %{
      a1: nil,
      d1: nil,
      g1: nil,
      b2: nil,
      d2: nil,
      f2: nil,
      c3: nil,
      d3: nil,
      e3: nil,
      a4: nil,
      b4: nil,
      c4: nil,
      e4: nil,
      f4: nil,
      g4: nil,
      d5: nil,
      c6: nil,
      d6: nil,
      e6: nil
    }
  end

  @spec mills_combinations() :: [[position()]]
  defp mills_combinations do
    [
      # Horizontal
      [:a1, :d1, :g1],
      [:b2, :d2, :f2],
      [:c3, :d3, :e3],
      [:a4, :b4, :c4],
      [:e4, :f4, :g4],
      [:c5, :d5, :e5],
      [:b6, :d6, :f6],
      [:a7, :d7, :g7],
      # Vertical
      [:a1, :a4, :a7],
      [:b2, :b4, :b6],
      [:c3, :c4, :c5],
      [:d1, :d2, :d3],
      [:d5, :d6, :d7],
      [:e3, :e4, :e5],
      [:f2, :f4, :f6],
      [:g1, :g4, :g7]
    ]
  end

  @spec can_remove_piece?(t(), position(), player()) :: boolean()
  defp can_remove_piece?(board, position, player) do
    !in_any_mill?(board, position, player) || all_opponent_pieces_in_mills?(board, player)
  end

  @spec in_any_mill?(t(), position(), player()) :: boolean()
  defp in_any_mill?(board, position, player) do
    Enum.any?(board.mills, fn mill ->
      Enum.member?(mill, position) &&
        Enum.all?(mill, fn pos -> board.positions[pos] == player end)
    end)
  end

  @spec all_opponent_pieces_in_mills?(t(), player()) :: boolean()
  defp all_opponent_pieces_in_mills?(board, player) do
    board.positions
    |> Enum.filter(fn {_, piece_owner} -> piece_owner == player end)
    |> Enum.all?(fn {pos, _} -> in_any_mill?(board, pos, player) end)
  end
end
