defmodule NineMensMorris.GameSupervisorTest do
  use ExUnit.Case, async: false
  alias NineMensMorris.GameSupervisor

  describe "start_link/1" do
    test "handles already started supervisor" do
      assert {:error, {:already_started, _pid}} = GameSupervisor.start_link([])
    end
  end

  describe "init/1" do
    test "initializes with one_for_one strategy" do
      {:ok, config} = GameSupervisor.init(:ok)
      assert config.strategy == :one_for_one
      assert config.intensity == 3
      assert config.period == 5
    end
  end

  describe "start_game/1" do
    test "starts a game process without password" do
      game_id = "test_supervisor_game_1"

      assert {:ok, pid} = GameSupervisor.start_game(game_id)
      assert Process.alive?(pid)

      assert [{^pid, _}] = NineMensMorris.GameRegistry.lookup(game_id)
    end

    test "starts a game process with password" do
      game_id = "test_supervisor_game_2"
      password = "secret123"

      assert {:ok, pid} = GameSupervisor.start_game(game_id, password)
      assert Process.alive?(pid)

      assert [{^pid, _}] = NineMensMorris.GameRegistry.lookup(game_id)
    end

    test "returns error for duplicate game_id" do
      game_id = "duplicate_game"

      {:ok, pid1} = GameSupervisor.start_game(game_id)
      assert Process.alive?(pid1)

      assert {:error, {:already_started, ^pid1}} = GameSupervisor.start_game(game_id)
    end
  end

  describe "supervision" do
    test "restarts game process if it crashes" do
      game_id = "crash_test_game"

      {:ok, pid1} = GameSupervisor.start_game(game_id)
      assert Process.alive?(pid1)

      Process.exit(pid1, :kill)
      :timer.sleep(100)

      [{pid2, _}] = NineMensMorris.GameRegistry.lookup(game_id)
      assert Process.alive?(pid2)
      assert pid1 != pid2
    end
  end
end
