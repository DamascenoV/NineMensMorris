defmodule NineMensMorrisWeb.GameLive do
  use NineMensMorrisWeb, :live_view
  alias NineMensMorris.Game
  alias NineMensMorris.BoardCoordinates

  @board_coordinates [
    {50, 50},
    {150, 50},
    {250, 50},
    {50, 150},
    {250, 150},
    {50, 250},
    {150, 250},
    {250, 250},
    {87, 87},
    {150, 87},
    {212, 87},
    {87, 150},
    {212, 150},
    {87, 212},
    {150, 212},
    {212, 212},
    {125, 125},
    {150, 125},
    {175, 125},
    {125, 150},
    {175, 150},
    {125, 175},
    {150, 175},
    {175, 175}
  ]

  @valid_positions [
    :a1,
    :d1,
    :g1,
    :b2,
    :d2,
    :f2,
    :c3,
    :d3,
    :e3,
    :a4,
    :b4,
    :c4,
    :e4,
    :f4,
    :g4,
    :c5,
    :d5,
    :e5,
    :b6,
    :d6,
    :f6,
    :a7,
    :d7,
    :g7
  ]

  @impl true
  def mount(%{"game_id" => game_id}, session, socket) do
    game = "game:#{game_id}"

    case Registry.lookup(NineMensMorris.GameRegistry, game_id) do
      [{_pid, _}] ->
        game_state = Game.get_game_state(game_id)
        socket = assign_initial_state(socket, game_id, game_state)

        if connected?(socket) do
          handle_connected_mount(socket, game, game_id, session)
        else
          {:ok, socket}
        end

      [] ->
        {:ok, push_navigate(socket, to: ~p"/lobby?error=Game not found")}
    end
  end

  defp handle_connected_mount(socket, game, game_id, session) do
    Phoenix.PubSub.subscribe(NineMensMorris.PubSub, game)
    {:ok, updated_socket} = join_game(socket, game_id, session)

    if updated_socket.assigns[:needs_presence_tracking] do
      Process.send_after(self(), :track_presence, 100)
    end

    {:ok, updated_socket}
  end

  defp assign_initial_state(socket, game_id, game_state) do
    placed_pieces = build_placed_pieces_from_board(game_state.board)

    socket
    |> assign(:game_id, game_id)
    |> assign(:player, nil)
    |> assign(board: game_state.board)
    |> assign(current_player: game_state.current_player)
    |> assign(board_coordinates: @board_coordinates)
    |> assign(placed_pieces: placed_pieces)
    |> assign(:winner, game_state.winner)
    |> assign(:game_full, false)
    |> assign(:awaiting_player, map_size(game_state.players) < 2)
    |> assign(:can_capture, false)
    |> assign(:captures, game_state.captures)
    |> assign(:selected_piece, nil)
    |> assign(:phase, game_state.phase)
    |> assign(:opponent_cursors, %{})
  end

  defp join_game(socket, game_id, session) do
    session_id = Map.get(session, "player_session_id") || generate_session_id()

    case Game.start_or_get(game_id) do
      {:ok, _pid} ->
        case Game.join(game_id, self(), session_id) do
          {:ok, player} ->
            updated_game_state = Game.get_game_state(game_id)
            updated_placed_pieces = build_placed_pieces_from_board(updated_game_state.board)

            {:ok,
             socket
             |> assign(:player, player)
             |> assign(:awaiting_player?, map_size(updated_game_state.players) < 2)
             |> assign(:current_player, updated_game_state.current_player)
             |> assign(:board, updated_game_state.board)
             |> assign(:placed_pieces, updated_placed_pieces)
             |> assign(:winner, updated_game_state.winner)
             |> assign(:captures, updated_game_state.captures)
             |> assign(:phase, updated_game_state.phase)
             |> assign(:player_session_id, session_id)
             |> assign(:needs_presence_tracking, true)}

          {:error, _reason} ->
            {:ok, socket |> assign(:game_full, true)}
        end

      {:error, _reason} ->
        {:ok, socket |> assign(:game_full, true)}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.assigns[:player] do
      NineMensMorrisWeb.Presence.untrack(
        self(),
        "game:#{socket.assigns.game_id}",
        socket.assigns.player
      )
    end
  end

  @impl true
  def handle_event("cursor_move", %{"x" => x, "y" => y}, socket) do
    player = socket.assigns.player
    game_id = socket.assigns.game_id

    if player do
      cursor_x = x
      cursor_y = y

      try do
        NineMensMorrisWeb.Presence.update_cursor(game_id, self(), player, cursor_x, cursor_y)
      rescue
        _ -> :ok
      end
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("place_piece", %{"position" => position_str}, socket) do
    with {:ok, position} <- validate_position(position_str),
         current_player = socket.assigns.current_player,
         true <- current_player == socket.assigns.player do
      case Game.place_piece(socket.assigns.game_id, position, current_player) do
        {:ok, new_board} ->
          coordinates = BoardCoordinates.get_coordinates(position)

          socket =
            socket
            |> assign(board: new_board)
            |> assign(current_player: next_player(current_player))
            |> update(:placed_pieces, fn pieces ->
              Map.put(pieces, coordinates, current_player)
            end)

          {:noreply, socket}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      _ ->
        {:noreply, socket |> put_flash(:error, "Not your turn")}
    end
  end

  @impl true
  def handle_event("remove_piece", %{"position" => position_str}, socket) do
    with {:ok, position} <- validate_position(position_str),
         true <-
           socket.assigns.can_capture && socket.assigns.current_player == socket.assigns.player do
      case Game.remove_piece(socket.assigns.game_id, position, socket.assigns.mill_forming_player) do
        {:ok, new_board} ->
          coordinates = BoardCoordinates.get_coordinates(position)

          socket =
            socket
            |> assign(board: new_board)
            |> assign(:can_capture, false)
            |> update(:placed_pieces, fn pieces ->
              Map.delete(pieces, coordinates)
            end)

          {:noreply, socket}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_piece", %{"position" => position_str}, socket) do
    with {:ok, position} <- validate_position(position_str),
         true <-
           socket.assigns.current_player == socket.assigns.player &&
             socket.assigns.board.positions[position] == socket.assigns.player do
      {:noreply, socket |> assign(:selected_piece, position)}
    else
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("move_piece", %{"position" => to_pos_str}, socket) do
    with {:ok, to_pos} <- validate_position(to_pos_str),
         from_pos = socket.assigns.selected_piece,
         current_player = socket.assigns.current_player,
         true <- from_pos && current_player == socket.assigns.player do
      case Game.move_piece(socket.assigns.game_id, from_pos, to_pos, current_player) do
        {:ok, new_board} ->
          coordinates_from = BoardCoordinates.get_coordinates(from_pos)
          coordinates_to = BoardCoordinates.get_coordinates(to_pos)

          socket =
            socket
            |> assign(board: new_board)
            |> assign(current_player: next_player(current_player))
            |> update(:placed_pieces, fn pieces ->
              pieces
              |> Map.delete(coordinates_from)
              |> Map.put(coordinates_to, current_player)
            end)
            |> assign(:selected_piece, nil)

          {:noreply, socket}

        {:error, _} ->
          {:noreply, socket |> assign(:selected_piece, nil)}
      end
    else
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:player_joined, _player}, socket) do
    socket =
      socket
      |> assign(:awaiting_player, false)
      |> assign(:current_player, Game.current_player(socket.assigns.game_id))

    {:noreply, socket |> put_flash(:info, "Player Join")}
  end

  @impl true
  def handle_info(
        {:piece_placed,
         %{
           position: position,
           player: player,
           current_player: current_player,
           phase: phase,
           coordinates: coordinates
         }},
        socket
      ) do
    socket =
      socket
      |> assign(
        board: %{
          socket.assigns.board
          | positions: Map.put(socket.assigns.board.positions, position, player)
        }
      )
      |> assign(:current_player, current_player)
      |> assign(:phase, phase)
      |> update(:placed_pieces, fn pieces ->
        Map.put(pieces, coordinates, player)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:piece_moved,
         %{
           from: from_pos,
           to: to_pos,
           player: player,
           coordinates_from: coordinates_from,
           coordinates_to: coordinates_to,
           phase: phase
         }},
        socket
      ) do
    socket =
      socket
      |> assign(
        board: %{
          socket.assigns.board
          | positions:
              socket.assigns.board.positions
              |> Map.put(from_pos, nil)
              |> Map.put(to_pos, player)
        }
      )
      |> assign(:current_player, next_player(player))
      |> assign(:phase, phase)
      |> update(:placed_pieces, fn pieces ->
        pieces
        |> Map.delete(coordinates_from)
        |> Map.put(coordinates_to, player)
      end)
      |> assign(:selected_piece, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:mill_formed, player, mills}, socket) do
    socket =
      socket
      |> assign(:can_capture, true)
      |> assign(:mill_forming_player, player)
      |> assign(:formed_mills, mills)
      |> assign(:current_player, next_player(socket.assigns.current_player))

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:piece_removed,
         %{
           position: position,
           player: _player,
           current_player: current_player,
           coordinates: coordinates,
           captures: captures
         }},
        socket
      ) do
    socket =
      socket
      |> assign(
        board: %{
          socket.assigns.board
          | positions: Map.delete(socket.assigns.board.positions, position)
        }
      )
      |> assign(:current_player, current_player)
      |> assign(:can_capture, false)
      |> assign(:captures, captures)
      |> update(:placed_pieces, fn pieces ->
        Map.delete(pieces, coordinates)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:player_left, _pid}, socket) do
    {:noreply, socket |> put_flash(:error, "Opponent Left the Game")}
  end

  @impl true
  def handle_info({:game_ended, :victory, player, by}, socket) do
    message =
      case by do
        :opponent_disconnected -> "Opponent didn't return within 3 minutes. You win!"
        _ -> "Game Ended by #{by}"
      end

    {:noreply, socket |> assign(:winner, player) |> put_flash(:info, message)}
  end

  @impl true
  def handle_info({:game_ended, :player_left}, socket) do
    {:noreply,
     socket |> assign(:winner, :game_abandoned) |> put_flash(:error, "Game ended - opponent left")}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: _diff}, socket) do
    try do
      presence_list = NineMensMorrisWeb.Presence.list_game(socket.assigns.game_id)

      opponent_cursors =
        presence_list
        |> Enum.filter(fn {player, _} -> player != socket.assigns.player end)
        |> Enum.map(fn {player, %{metas: [meta | _]}} ->
          {player, %{x: meta.cursor_x, y: meta.cursor_y}}
        end)
        |> Map.new()

      {:noreply, assign(socket, :opponent_cursors, opponent_cursors)}
    rescue
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:track_presence, socket) do
    if socket.assigns[:needs_presence_tracking] && socket.assigns[:player] do
      try do
        NineMensMorrisWeb.Presence.track_cursor(
          socket.assigns.game_id,
          self(),
          socket.assigns.player,
          0,
          0
        )

        {:noreply, assign(socket, :needs_presence_tracking, false)}
      rescue
        _ -> {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  defp player_color(player) when player in [:white, "white"], do: "white"
  defp player_color(player) when player in [:black, "black"], do: "black"

  defp next_player(:white), do: :black
  defp next_player(:black), do: :white

  defp validate_position(position_str) do
    try do
      position = String.to_existing_atom(position_str)
      if position in @valid_positions, do: {:ok, position}, else: :error
    rescue
      ArgumentError -> :error
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end

  defp build_placed_pieces_from_board(board) do
    board.positions
    |> Enum.filter(fn {_position, player} -> player != nil end)
    |> Enum.map(fn {position, player} ->
      coordinates = BoardCoordinates.get_coordinates(position)
      {coordinates, player}
    end)
    |> Map.new()
  end
end
