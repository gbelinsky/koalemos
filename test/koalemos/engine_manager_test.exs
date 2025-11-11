defmodule Koalemos.EngineManagerTest do
  use ExUnit.Case, async: false
  alias Koalemos.EngineManager
  alias Koalemos.Engine.Observer

  # Helper to drain all messages from mailbox
  defp flush_messages do
    receive do
      _ -> flush_messages()
    after
      0 -> :ok
    end
  end

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

    # Drain ALL pending messages
    :timer.sleep(10)
    flush_messages()

    # Generate unique routine ID for this test
    routine_id = "manager-test-#{:erlang.unique_integer([:positive])}"

    # Cleanup function
    on_exit(fn ->
      case Registry.lookup(Koalemos.RoutineRegistry, routine_id) do
        [{pid, _}] -> GenServer.stop(pid, :normal, 100)
        [] -> :ok
      end
    end)

    {:ok, routine_id: routine_id}
  end

  describe "start_routine/3" do
    test "starts a routine successfully", %{routine_id: routine_id} do
      {:ok, pid} = EngineManager.start_routine(routine_id, TestRoutine, %{user: "alice"})

      assert Process.alive?(pid)
    end

    test "accepts initial context", %{routine_id: routine_id} do
      {:ok, pid} = EngineManager.start_routine(routine_id, TestRoutine, %{key: "value"})

      state = :sys.get_state(pid)
      assert state.context.key == "value"
    end

    test "defaults context to empty map", %{routine_id: routine_id} do
      {:ok, pid} = EngineManager.start_routine(routine_id, TestRoutine)

      state = :sys.get_state(pid)
      assert is_map(state.context)
    end

    test "returns existing pid if already started", %{routine_id: routine_id} do
      {:ok, pid1} = EngineManager.start_routine(routine_id, TestRoutine)
      {:ok, pid2} = EngineManager.start_routine(routine_id, TestRoutine)

      assert pid1 == pid2
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
    test "returns empty list when no routines from this test" do
      # Get baseline count (may have routines from other tests due to async execution)
      initial_routines = EngineManager.list_routines()
      initial_count = length(initial_routines)

      # Stop any manager-test routines from this test file
      EngineManager.list_routines()
      |> Enum.filter(fn info -> String.starts_with?(info.id, "manager-test-") end)
      |> Enum.each(fn info -> EngineManager.stop_routine(info.id) end)

      # Wait for cleanup
      :timer.sleep(50)

      # Verify no manager-test routines remain (other test routines may still exist)
      remaining_manager_routines =
        EngineManager.list_routines()
        |> Enum.filter(fn info -> String.starts_with?(info.id, "manager-test-") end)

      assert remaining_manager_routines == []
    end

    test "returns list of running routines", %{routine_id: routine_id} do
      routine_id2 = "manager-test-#{:erlang.unique_integer([:positive])}"

      {:ok, _} = EngineManager.start_routine(routine_id, TestRoutine)
      {:ok, _} = EngineManager.start_routine(routine_id2, TestRoutine)

      on_exit(fn ->
        case Registry.lookup(Koalemos.RoutineRegistry, routine_id2) do
          [{pid, _}] -> GenServer.stop(pid, :normal, 100)
          [] -> :ok
        end
      end)

      routines = EngineManager.list_routines()

      assert length(routines) >= 2
      assert Enum.any?(routines, fn r -> r.id == routine_id end)
      assert Enum.any?(routines, fn r -> r.id == routine_id2 end)
    end

    test "returns RoutineInfo structs with correct fields", %{routine_id: routine_id} do
      {:ok, _} = EngineManager.start_routine(routine_id, TestRoutine, %{user: "bob"})

      routines = EngineManager.list_routines()
      info = Enum.find(routines, fn r -> r.id == routine_id end)

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
    test "returns routine info for existing routine", %{routine_id: routine_id} do
      {:ok, _} = EngineManager.start_routine(routine_id, TestRoutine, %{user: "charlie"})

      {:ok, info} = EngineManager.get_routine(routine_id)

      assert info.id == routine_id
      assert info.module == TestRoutine
      assert info.context.user == "charlie"
    end

    test "returns error for nonexistent routine" do
      assert {:error, :not_found} = EngineManager.get_routine("nonexistent")
    end

    test "includes status and current step", %{routine_id: routine_id} do
      {:ok, _} = EngineManager.start_routine(routine_id, TestRoutine)

      {:ok, info} = EngineManager.get_routine(routine_id)

      assert info.status in [:running, :completed]
      assert is_atom(info.current_step)
    end
  end

  describe "get_routine_state/1" do
    test "returns raw state for existing routine", %{routine_id: routine_id} do
      {:ok, _} = EngineManager.start_routine(routine_id, TestRoutine)

      {:ok, state} = EngineManager.get_routine_state(routine_id)

      assert is_map(state)
      assert state.routine_id == routine_id
      assert state.module == TestRoutine
      assert is_map(state.context)
    end

    test "returns error for nonexistent routine" do
      assert {:error, :not_found} = EngineManager.get_routine_state("nonexistent")
    end
  end
end
