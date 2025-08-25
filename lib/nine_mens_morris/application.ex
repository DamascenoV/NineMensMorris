defmodule NineMensMorris.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NineMensMorrisWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:nine_mens_morris, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: NineMensMorris.PubSub},
      NineMensMorrisWeb.Presence,
      NineMensMorrisWeb.Endpoint,
      NineMensMorris.GameRegistry,
      NineMensMorris.GameSupervisor
    ]

    opts = [strategy: :one_for_one, name: NineMensMorris.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    NineMensMorrisWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
