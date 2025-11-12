defmodule Koalemos.IntegrationTestCase do
  @moduledoc """
  Shared setup and helpers for integration tests.

  Provides:
  - Registry and Observer startup
  - Credential checking and skip helpers
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

        [] ->
          :ok
      end
    end)

    {:ok, routine_id: routine_id}
  end

  @doc """
  Check if credentials are available at standard location.

  Returns true if .koalemos/.credentials.json exists and is readable.
  """
  def credentials_available? do
    creds_path = ".koalemos/.credentials.json"
    File.exists?(creds_path) && File.regular?(creds_path)
  end

  @doc """
  Skip test if credentials not available, otherwise start SimpleCredentialManager.

  Usage in test:
  ```
  test "real API call", %{routine_id: id} do
    case skip_if_no_credentials() do
      :ok -> # run test
      :skip -> :ok # skip
    end
  end
  ```

  This function will:
  - Return :skip if no credentials available
  - Start SimpleCredentialManager if not running
  - Set KOALEMOS_CREDENTIALS_PATH env var
  - Return :ok when ready
  """
  def skip_if_no_credentials do
    if credentials_available?() do
      # Set env var to credentials path
      creds_path = Path.expand(".koalemos/.credentials.json")
      System.put_env("KOALEMOS_CREDENTIALS_PATH", creds_path)

      # Start SimpleCredentialManager if not running
      case GenServer.whereis(Koalemos.SimpleCredentialManager) do
        nil ->
          # Start the manager
          case GenServer.start_link(Koalemos.SimpleCredentialManager, [],
                 name: Koalemos.SimpleCredentialManager
               ) do
            {:ok, _pid} -> :ok
            {:error, {:already_started, _pid}} -> :ok
          end

        _pid ->
          :ok
      end

      :ok
    else
      IO.puts("\nSkipping test - credentials not available at .koalemos/.credentials.json")
      :skip
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
      IO.puts("\nSkipping test - Ollama server not running at localhost:11434")
      :skip
    else
      :ok
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
