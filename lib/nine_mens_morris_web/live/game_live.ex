defmodule NineMensMorrisWeb.GameLive do
  use NineMensMorrisWeb, :live_view

  alias NineMensMorris.Game
  alias NineMensMorris.Board

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center h-screen">
      <div class="mb-8">
        <p class="text-gray-300 text-lg mb-2">Share this game URL with a friend</p>
      </div>

      <%= if @game_full do %>
        <p class="text-red-500 text-2xl mb-4">Game is full. Please try again later.</p>
      <% else %>
        <%= if @awaiting_player do %>
          <p class="text-blue-500 text-2xl mb-4">
            You are player {@player}. Waiting for another player to join...
          </p>
        <% else %>
          <div class="board" />
        <% end %>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(%{"game_id" => game_id}, _session, socket) do
    topic = "game:#{game_id}"

    socket =
      socket
      |> assign(:game_id, game_id)
      |> assign(:player, nil)
      |> assign(:board, [])
      |> assign(:winner, nil)
      |> assign(:game_full, false)
      |> assign(:awaiting_player, true)
      |> assign(:current_player, nil)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(NineMensMorris.PubSub, topic)

      case Game.start_or_get(game_id) do
        {:ok, _pid} ->
          case Game.join(game_id, self()) do
            {:ok, player} ->
              {:ok,
               socket
               |> assign(:player, player)
               |> assign(:awaiting_player, Game.awaiting_player?(game_id))
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
  def handle_info({:player_joined, _player}, socket) do
    socket =
      socket
      |> assign(:awaiting_player, false)
      |> assign(:current_player, Game.current_player(socket.assigns.game_id))

    {:noreply, socket}
  end
end
