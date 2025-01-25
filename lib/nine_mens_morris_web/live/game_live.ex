defmodule NineMensMorrisWeb.GameLive do
  use NineMensMorrisWeb, :live_view
  alias NineMensMorris.Game
  alias NineMensMorris.Board
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

  @impl true
  def mount(%{"game_id" => game_id}, _session, socket) do
    game = "game:#{game_id}"

    {:ok, game_state} = Game.init(game_id)

    socket =
      socket
      |> assign(:game_id, game_id)
      |> assign(:player, nil)
      |> assign(board: game_state.board)
      |> assign(current_player: nil)
      |> assign(board_coordinates: @board_coordinates)
      |> assign(placed_pieces: %{})
      |> assign(:winner, nil)
      |> assign(:game_full, false)
      |> assign(:awaiting_player, true)
      |> assign(:can_capture, false)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(NineMensMorris.PubSub, game)

      case Game.start_or_get(game_id) do
        {:ok, _pid} ->
          case Game.join(game_id, self()) do
            {:ok, player} ->
              {:ok,
               socket
               |> assign(:player, player)
               |> assign(:awaiting_player?, true)
               |> assign(:current_player, Game.current_player(game_id))}

            {:error, _reason} ->
              {:ok, socket |> assign(:game_full, true)}
          end

        {:error, _reason} ->
          {:ok, socket |> assign(:game_full, true)}
      end
    else
      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @game_full do %>
      <p class="text-red-500 text-2xl mb-4">Game is full. Please try again later.</p>
    <% else %>
      <%= if @awaiting_player do %>
        <p class="text-blue-500 text-2xl mb-4">
          You are player {@player}. Waiting for another player to join...
        </p>
      <% else %>
        <%= if @can_capture do %>
          <p class="text-red-500 text-2xl mb-4">
            Mill formed! Select an opponent's piece to remove.
          </p>
        <% else %>
          <%= if @current_player == @player do %>
            Your turn ({@player})
          <% else %>
            Waiting for opponent's turn...
          <% end %>
        <% end %>
        <div class="game-container bg-gray-200">
          <svg viewBox="0 0 300 300" width="100%" height="100%">
            <rect x="50" y="50" width="200" height="200" fill="none" stroke="black" stroke-width="2" />
            <rect x="87" y="87" width="125" height="125" fill="none" stroke="black" stroke-width="2" />
            <rect x="125" y="125" width="50" height="50" fill="none" stroke="black" stroke-width="2" />
            <line x1="150" y1="50" x2="150" y2="125" stroke="black" stroke-width="2" />
            <line x1="150" y1="175" x2="150" y2="250" stroke="black" stroke-width="2" />
            <line x1="50" y1="150" x2="125" y2="150" stroke="black" stroke-width="2" />
            <line x1="175" y1="150" x2="250" y2="150" stroke="black" stroke-width="2" />
            <%= for {x, y} <- @board_coordinates do %>
              <circle
                cx={x}
                cy={y}
                r="5"
                fill="gray"
                phx-click={if @can_capture, do: "remove_piece", else: "place_piece"}
                phx-value-position={BoardCoordinates.get_position(x, y)}
              />
            <% end %>
            <%= for {{x, y}, player} <- @placed_pieces do %>
              <circle
                cx={x}
                cy={y}
                r="10"
                fill={player_color(player)}
                phx-click={
                  if @can_capture and player != @mill_forming_player, do: "remove_piece", else: nil
                }
                phx-value-position={BoardCoordinates.get_position(x, y)}
              />
            <% end %>
          </svg>

          <div class="game-info">
            <p>Current Player: {@current_player}</p>
            <p>Pieces Left - White: {@board.pieces.white}, Black: {@board.pieces.black}</p>
          </div>
        </div>
      <% end %>
    <% end %>
    """
  end

  @impl true
  def handle_event("place_piece", %{"position" => position_str}, socket) do
    position = String.to_atom(position_str)
    current_player = socket.assigns.current_player

    dbg(socket)

    if current_player == socket.assigns.player do
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
      {:noreply, socket |> put_flash(:error, "Not your turn")}
    end
  end

  @impl true
  def handle_event("remove_piece", %{"position" => position_str}, socket) do
    position = String.to_atom(position_str)

    if socket.assigns.can_capture and socket.assigns.current_player == socket.assigns.player do
      case Board.remove_piece(socket.assigns.board, position, socket.assigns.mill_forming_player) do
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
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:player_joined, _player}, socket) do
    socket =
      socket
      |> assign(:awaiting_player, false)
      |> assign(:current_player, Game.current_player(socket.assigns.game_id))

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:piece_placed, %{position: position, player: player, current_player: current_player, coordinates: coordinates}},
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
      |> update(:placed_pieces, fn pieces ->
        Map.put(pieces, coordinates, player)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:mill_formed, player, mills}, socket) do
    socket =
      socket
      |> assign(:can_capture, true)
      |> assign(:mill_forming_player, player)
      |> assign(:formed_mills, mills)

    {:noreply, socket}
  end


  defp player_color(:white), do: "white"
  defp player_color(:black), do: "black"

  defp next_player(:white), do: :black
  defp next_player(:black), do: :white
end

