defmodule NineMensMorris.ApplicationTest do
  use ExUnit.Case, async: true

  test "start/2 starts the application successfully" do
    assert Process.whereis(NineMensMorris.Supervisor) != nil
    assert Process.whereis(NineMensMorris.GameRegistry) != nil
    assert Process.whereis(NineMensMorris.GameSupervisor) != nil
  end

  test "supervision tree includes required processes" do
    children = Supervisor.which_children(NineMensMorris.Supervisor)

    process_names = Enum.map(children, fn {name, _pid, _type, _modules} -> name end)

    assert NineMensMorris.GameRegistry in process_names
    assert NineMensMorris.GameSupervisor in process_names
  end

  test "game registry is properly configured" do
    assert Process.alive?(Process.whereis(NineMensMorris.GameRegistry))

    game_id = "test_registry_game"
    {:ok, _agent_pid} = Agent.start_link(fn -> :ok end)

    {:ok, _} = Registry.register(NineMensMorris.GameRegistry, game_id, :test_data)

    [{found_pid, :test_data}] = NineMensMorris.GameRegistry.lookup(game_id)
    assert is_pid(found_pid)
    assert Process.alive?(found_pid)
  end

  test "game supervisor is properly configured" do
    assert Process.alive?(Process.whereis(NineMensMorris.GameSupervisor))

    game_id = "test_supervised_game"
    assert {:ok, game_pid} = NineMensMorris.GameSupervisor.start_game(game_id)
    assert Process.alive?(game_pid)

    assert [{^game_pid, _}] = NineMensMorris.GameRegistry.lookup(game_id)
  end
end
