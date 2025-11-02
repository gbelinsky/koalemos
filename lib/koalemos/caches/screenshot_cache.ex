defmodule Koalemos.Caches.ScreenshotCache do
  @moduledoc """
  GenServer for storing screenshots captured from wireframe preview pages.

  Provides in-memory storage of Base64-encoded PNG screenshots, keyed by routine ID.
  Screenshots are stored until explicitly cleared or the routine completes.

  ## Usage

      alias Koalemos.Caches.ScreenshotCache

      # Store a screenshot
      ScreenshotCache.put("routine-123", "iVBORw0KGgoAAAANS...")

      # Retrieve a screenshot
      {:ok, image} = ScreenshotCache.get("routine-123")

      # Clear a screenshot
      ScreenshotCache.clear("routine-123")

      # Clear all screenshots (useful for testing)
      ScreenshotCache.clear_all()

  ## Storage Format

  Screenshots are stored as:
  ```
  %{
    routine_id => %{
      image: base64_string,
      captured_at: DateTime
    }
  }
  ```

  ## Future Enhancements

  - TTL/expiration (M5)
  - Size limits and eviction (M5)
  - Disk persistence for large images (M5)
  """

  use GenServer
  require Logger

  # Client API

  @doc """
  Start the ScreenshotCache GenServer.

  Registered as a named process for easy access throughout the application.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Store a screenshot for a given routine.

  ## Parameters

  - `routine_id` - The routine identifier (string)
  - `image` - Base64-encoded PNG image data (string)

  ## Returns

  `:ok`

  ## Examples

      iex> ScreenshotCache.put("routine-123", "iVBORw0KGgoAAAANS...")
      :ok
  """
  @spec put(String.t(), String.t()) :: :ok
  def put(routine_id, image) when is_binary(routine_id) and is_binary(image) do
    GenServer.cast(__MODULE__, {:put, routine_id, image})
  end

  @doc """
  Retrieve a screenshot for a given routine.

  ## Parameters

  - `routine_id` - The routine identifier (string)

  ## Returns

  - `{:ok, image}` if screenshot exists
  - `{:error, :not_found}` if no screenshot for this routine

  ## Examples

      iex> ScreenshotCache.put("routine-123", "image_data")
      iex> ScreenshotCache.get("routine-123")
      {:ok, "image_data"}

      iex> ScreenshotCache.get("nonexistent")
      {:error, :not_found}
  """
  @spec get(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get(routine_id) when is_binary(routine_id) do
    GenServer.call(__MODULE__, {:get, routine_id})
  end

  @doc """
  Clear the screenshot for a given routine.

  ## Parameters

  - `routine_id` - The routine identifier (string)

  ## Returns

  `:ok` (always succeeds, even if no screenshot exists)

  ## Examples

      iex> ScreenshotCache.clear("routine-123")
      :ok
  """
  @spec clear(String.t()) :: :ok
  def clear(routine_id) when is_binary(routine_id) do
    GenServer.cast(__MODULE__, {:clear, routine_id})
  end

  @doc """
  Clear all screenshots.

  Useful for testing or manual cleanup.

  ## Returns

  `:ok`

  ## Examples

      iex> ScreenshotCache.clear_all()
      :ok
  """
  @spec clear_all() :: :ok
  def clear_all do
    GenServer.cast(__MODULE__, :clear_all)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    Logger.info("[ScreenshotCache] Starting")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:put, routine_id, image}, state) do
    entry = %{
      image: image,
      captured_at: DateTime.utc_now()
    }

    new_state = Map.put(state, routine_id, entry)
    Logger.debug("[ScreenshotCache] Stored screenshot for routine #{routine_id}")

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:clear, routine_id}, state) do
    new_state = Map.delete(state, routine_id)
    Logger.debug("[ScreenshotCache] Cleared screenshot for routine #{routine_id}")

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:clear_all, _state) do
    Logger.debug("[ScreenshotCache] Cleared all screenshots")
    {:noreply, %{}}
  end

  @impl true
  def handle_call({:get, routine_id}, _from, state) do
    case Map.get(state, routine_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{image: image} ->
        {:reply, {:ok, image}, state}
    end
  end
end
