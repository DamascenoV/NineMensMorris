defmodule NineMensMorris.GameRegistryTest do
  use ExUnit.Case, async: true
  alias NineMensMorris.GameRegistry

  describe "start_link/1" do
    test "handles already started registry" do
      assert {:error, {:already_started, _pid}} = GameRegistry.start_link([])
    end
  end

  describe "child_spec/1" do
    test "returns a valid child specification" do
      spec = GameRegistry.child_spec([])

      assert spec.id == GameRegistry
      assert spec.start == {GameRegistry, :start_link, [[]]}
      assert spec.type == :supervisor
    end
  end

  describe "via_tuple/1" do
    test "returns correct registry tuple for game_id" do
      game_id = "test_game_123"
      expected = {:via, Registry, {GameRegistry, game_id}}

      assert GameRegistry.via_tuple(game_id) == expected
    end
  end

  describe "lookup/1" do
    test "returns empty list for non-existent game" do
      assert GameRegistry.lookup("non_existent_game") == []
    end

    test "returns process information for registered game" do
      game_id = "test_lookup_game"
      {:ok, _pid} = Agent.start_link(fn -> :ok end)

      {:ok, _} = Registry.register(NineMensMorris.GameRegistry, game_id, :game_data)

      [{found_pid, :game_data}] = NineMensMorris.GameRegistry.lookup(game_id)
      assert is_pid(found_pid)
      assert Process.alive?(found_pid)
    end
  end
end
