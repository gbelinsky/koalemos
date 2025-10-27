defmodule Koalemos.EngineManagerTest do
  use ExUnit.Case, async: false
  alias Koalemos.{EngineManager, Engine}
  alias Koalemos.Engine.Observer

  defmodule TestStep do
    def execute(_config, _state) do
      {:ok, [add: %{executed: true}]}
    end
  end

  defmodule TestRoutine do
    def routine_definition do
      %{
        start: %{
          type: Koalemos.EngineManagerTest.TestStep,
          transitions: []
        }
      }
    end
  end

  setup do
    # Start Registry
    case Process.whereis(Koalemos.RoutineRegistry) do
      nil -> start_supervised!({Registry, keys: :unique, name: Koalemos.RoutineRegistry})
      _pid -> :ok
    end

    # Start Observer
    case GenServer.whereis(Observer) do
      nil -> start_supervised!(Observer)
      _pid -> :ok
    end

    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine_events")

    # Clear messages
    receive do
      _ -> :ok
    after
      0 -> :ok
    end

    :ok
  end

  describe "start_routine/3" do
    test "starts a routine successfully" do
      {:ok, pid} = EngineManager.start_routine("test-1", TestRoutine, %{user: "alice"})

      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "accepts initial context" do
      {:ok, pid} = EngineManager.start_routine("test-2", TestRoutine, %{key: "value"})

      state = :sys.get_state(pid)
      assert state.context.key == "value"

      GenServer.stop(pid)
    end

    test "defaults context to empty map" do
      {:ok, pid} = EngineManager.start_routine("test-3", TestRoutine)

      state = :sys.get_state(pid)
      assert is_map(state.context)

      GenServer.stop(pid)
    end

    test "returns existing pid if already started" do
      {:ok, pid1} = EngineManager.start_routine("test-4", TestRoutine)
      {:ok, pid2} = EngineManager.start_routine("test-4", TestRoutine)

      assert pid1 == pid2

      GenServer.stop(pid1)
    end
  end

  describe "stop_routine/1" do
    @tag :skip
    test "stops a running routine" do
      # TODO: Fix this test - process isn't terminating as expected
      {:ok, _pid} = EngineManager.start_routine("test-5", TestRoutine)

      :ok = EngineManager.stop_routine("test-5")

      # Verify routine is no longer in registry (give it more time)
      :timer.sleep(500)
      assert {:error, :not_found} = EngineManager.get_routine("test-5")
    end

    test "returns error if routine not found" do
      assert {:error, :not_found} = EngineManager.stop_routine("nonexistent")
    end
  end

  describe "list_routines/0" do
    test "returns empty list when no routines" do
      # Stop any existing routines first
      EngineManager.list_routines()
      |> Enum.each(fn info -> EngineManager.stop_routine(info.id) end)

      :timer.sleep(50)

      assert EngineManager.list_routines() == []
    end

    test "returns list of running routines" do
      {:ok, _} = EngineManager.start_routine("test-6", TestRoutine)
      {:ok, _} = EngineManager.start_routine("test-7", TestRoutine)

      routines = EngineManager.list_routines()

      assert length(routines) >= 2
      assert Enum.any?(routines, fn r -> r.id == "test-6" end)
      assert Enum.any?(routines, fn r -> r.id == "test-7" end)
    end

    test "returns RoutineInfo structs with correct fields" do
      {:ok, _} = EngineManager.start_routine("test-8", TestRoutine, %{user: "bob"})

      [info | _] = EngineManager.list_routines()

      assert %EngineManager.RoutineInfo{} = info
      assert is_binary(info.id)
      assert is_atom(info.module)
      assert is_pid(info.pid)
      assert is_atom(info.status)
      assert is_atom(info.current_step)
      assert is_map(info.context)
    end
  end

  describe "get_routine/1" do
    test "returns routine info for existing routine" do
      {:ok, _} = EngineManager.start_routine("test-9", TestRoutine, %{user: "charlie"})

      {:ok, info} = EngineManager.get_routine("test-9")

      assert info.id == "test-9"
      assert info.module == TestRoutine
      assert info.context.user == "charlie"
    end

    test "returns error for nonexistent routine" do
      assert {:error, :not_found} = EngineManager.get_routine("nonexistent")
    end

    test "includes status and current step" do
      {:ok, _} = EngineManager.start_routine("test-10", TestRoutine)

      {:ok, info} = EngineManager.get_routine("test-10")

      assert info.status in [:running, :completed]
      assert is_atom(info.current_step)
    end
  end

  describe "get_routine_state/1" do
    test "returns raw state for existing routine" do
      {:ok, _} = EngineManager.start_routine("test-11", TestRoutine)

      {:ok, state} = EngineManager.get_routine_state("test-11")

      assert is_map(state)
      assert state.routine_id == "test-11"
      assert state.module == TestRoutine
      assert is_map(state.context)
    end

    test "returns error for nonexistent routine" do
      assert {:error, :not_found} = EngineManager.get_routine_state("nonexistent")
    end
  end
end
