defmodule NineMensMorrisWeb.LobbyLive do
  use NineMensMorrisWeb, :live_view

  alias NineMensMorris.Game

  @impl true
  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:join_form, to_form(%{"game_id" => "", "password" => ""}))
      |> assign(
        :create_form,
        to_form(%{"password" => "", "is_private" => "false"})
      )
      |> assign(:error, nil)
      |> assign(
        :player_session_id,
        Map.get(session, "player_session_id") || generate_session_id()
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("join_game", %{"game_id" => game_id, "password" => password}, socket) do
    game_id = String.trim(game_id)

    if game_id == "" do
      {:noreply, assign(socket, :error, "Please enter a game ID")}
    else
      join_game(socket, game_id, password)
    end
  end

  @impl true
  def handle_event(
        "create_game",
        %{"password" => password, "is_private" => is_private},
        socket
      ) do
    password = String.trim(password)
    is_private = is_private == "true"

    if is_private && password == "" do
      {:noreply, assign(socket, :error, "Private games require a password")}
    else
      create_game(socket, is_private, password)
    end
  end

  @impl true
  def handle_event("validate_join", %{"game_id" => game_id, "password" => password}, socket) do
    form = to_form(%{"game_id" => game_id, "password" => password})
    {:noreply, assign(socket, :join_form, form)}
  end

  @impl true
  def handle_event(
        "validate_create",
        %{"password" => password, "is_private" => is_private},
        socket
      ) do
    form = to_form(%{"password" => password, "is_private" => is_private})
    {:noreply, assign(socket, :create_form, form)}
  end

  @impl true
  def handle_event("clear_error", _params, socket) do
    {:noreply, assign(socket, :error, nil)}
  end

  @impl true
  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    query = URI.decode_query(uri.query || "")
    error = query["error"]

    if error do
      {:noreply, assign(socket, :error, error)}
    else
      {:noreply, socket}
    end
  end

  defp join_game(socket, game_id, password) do
    session_id = socket.assigns.player_session_id || generate_session_id()

    case Game.join_game(game_id, password, session_id) do
      {:ok, _pid} ->
        {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}?session_id=#{session_id}")}

      {:error, reason} ->
        {:noreply, assign(socket, :error, map_join_error(reason))}
    end
  end

  defp map_join_error(reason) do
    case reason do
      :game_not_found -> "Game not found"
      :invalid_password -> "Incorrect password"
      :game_full -> "Game is full"
      _ -> "Failed to join game: #{inspect(reason)}"
    end
  end

  defp create_game(socket, is_private, password) do
    game_password = if is_private, do: password, else: nil

    game_id = generate_unique_game_id()

    case Game.create_game(game_id, game_password) do
      {:ok, _pid} ->
        {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}")}

      {:error, :game_exists} ->
        {:noreply, assign(socket, :error, "Game ID already exists")}

      {:error, reason} ->
        {:noreply, assign(socket, :error, "Failed to create game: #{inspect(reason)}")}
    end
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end

  defp generate_unique_game_id do
    id =
      :crypto.strong_rand_bytes(4)
      |> Base.encode32(case: :lower)
      |> binary_part(0, 6)

    case Registry.lookup(NineMensMorris.GameRegistry, id) do
      [] -> id
      _ -> generate_unique_game_id()
    end
  end
end
