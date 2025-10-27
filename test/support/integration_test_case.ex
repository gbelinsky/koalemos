defmodule Koalemos.IntegrationTestCase do
  @moduledoc """
  Shared setup and helpers for integration tests.

  Provides:
  - Registry and Observer startup
  - Credential loading from Flo project (safely)
  - Test routine cleanup
  - Skip helpers for missing dependencies
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Koalemos.IntegrationTestCase
      alias Koalemos.EngineManager
      alias Koalemos.Engine
      alias Koalemos.Engine.Observer
    end
  end

  setup do
    # Start Registry if not running
    case Process.whereis(Koalemos.RoutineRegistry) do
      nil -> start_supervised!({Registry, keys: :unique, name: Koalemos.RoutineRegistry})
      _pid -> :ok
    end

    # Start Observer if not running
    case GenServer.whereis(Koalemos.Engine.Observer) do
      nil -> start_supervised!(Koalemos.Engine.Observer)
      _pid -> :ok
    end

    # Subscribe to events
    Phoenix.PubSub.subscribe(Koalemos.PubSub, "routine_events")

    # Drain pending messages
    :timer.sleep(10)
    flush_messages()

    # Generate unique routine ID
    routine_id = "integration-test-#{:erlang.unique_integer([:positive])}"

    # Cleanup function
    on_exit(fn ->
      case Registry.lookup(Koalemos.RoutineRegistry, routine_id) do
        [{pid, _}] when is_pid(pid) ->
          if Process.alive?(pid), do: GenServer.stop(pid, :normal, 100)
        [] -> :ok
      end
    end)

    {:ok, routine_id: routine_id}
  end

  @doc """
  Load credentials from Flo project (parent directory).

  Returns {:ok, credentials_map} or {:error, reason}

  Never logs or prints credentials.
  """
  def load_flo_credentials do
    # Try to load from parent Flo project
    flo_path = Path.join([File.cwd!(), "..", "flo", ".flo", ".credentials.json"])

    case File.read(flo_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, creds} -> {:ok, creds}
          {:error, _} -> {:error, :invalid_json}
        end
      {:error, :enoent} ->
        {:error, :not_found}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Skip test if Flo credentials not available.

  Usage in test:
  ```
  test "real API call", %{routine_id: id} do
    skip_if_no_flo_credentials()
    # ... test code using real API
  end
  ```
  """
  def skip_if_no_flo_credentials do
    case load_flo_credentials() do
      {:ok, _} -> :ok
      {:error, _} -> raise ExUnit.SkipError, message: "Flo credentials not available"
    end
  end

  @doc """
  Check if Ollama server is running on localhost.
  """
  def ollama_running? do
    case Req.get("http://localhost:11434/api/tags") do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  end

  @doc """
  Skip test if Ollama not running.
  """
  def skip_if_no_ollama do
    unless ollama_running?() do
      raise ExUnit.SkipError, message: "Ollama server not running at localhost:11434"
    end
  end

  @doc """
  Drain all messages from mailbox.
  """
  def flush_messages do
    receive do
      _ -> flush_messages()
    after
      0 -> :ok
    end
  end
end
