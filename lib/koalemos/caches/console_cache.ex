defmodule Koalemos.Caches.ConsoleCache do
  @moduledoc """
  GenServer for storing console output from wireframe previews with built-in
  rate limiting and infinite loop protection.

  Protects against console spam from runaway wireframe JavaScript that could
  overwhelm the system or agents.

  ## Usage

      alias Koalemos.Caches.ConsoleCache

      # Add a console message
      message = %{
        level: "log",
        message: "Hello from wireframe",
        timestamp: System.system_time(:millisecond)
      }
      ConsoleCache.add_message("routine-123", message)

      # Get messages (most recent first)
      messages = ConsoleCache.get_messages("routine-123", limit: 50)

      # Get messages since timestamp
      messages = ConsoleCache.get_messages("routine-123", since: 1730400000000)

      # Get messages by level
      errors = ConsoleCache.get_messages("routine-123", level: "error")

      # Clear messages
      ConsoleCache.clear_messages("routine-123")

  ## Rate Limiting

  Protects against infinite loop console spam:
  - Max 15 messages/second per routine
  - Max 10 duplicate messages within 5-second window
  - Max 500 total messages per routine (oldest messages are dropped when limit reached)
  - Automatic cleanup every 30 seconds (only removes old rate limit tracking data)
  - NO TTL on messages - they persist for the entire session

  When rate limits are hit, warning messages are inserted instead.
  """

  use GenServer
  require Logger

  # Rate limiting settings
  @max_messages_per_second 15
  @max_duplicate_messages 10
  # Clean up rate tracking data every 30 seconds
  @cleanup_interval_ms 30_000
  # Rate tracking data expires after 5 minutes
  @rate_data_ttl_ms 300_000
  @max_messages_per_routine 500
  # Only count duplicates within 5 seconds
  @duplicate_time_window_ms 5000

  # Client API

  @doc """
  Start the ConsoleCache GenServer.

  Registered as a named process for easy access throughout the application.
  """
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Add a console message with rate limiting and duplicate detection.

  ## Parameters

  - `routine_id` - The routine identifier (string)
  - `message` - Map with keys: `:level`, `:message`, `:timestamp`

  ## Returns

  - `:ok` if message was added
  - `{:error, :rate_limit}` if rate limit exceeded
  - `{:error, :duplicate_spam}` if duplicate limit exceeded

  When rate limits are hit, a warning message is stored instead of the actual message.

  ## Examples

      iex> message = %{level: "log", message: "test", timestamp: 123}
      iex> ConsoleCache.add_message("routine-123", message)
      :ok
  """
  @spec add_message(String.t(), map()) :: :ok | {:error, atom()}
  def add_message(routine_id, message) when is_binary(routine_id) and is_map(message) do
    GenServer.call(__MODULE__, {:add_message, routine_id, message})
  end

  @doc """
  Get console messages for a routine with optional filtering.

  ## Parameters

  - `routine_id` - The routine identifier (string)
  - `opts` - Keyword list with optional filters:
    - `:since` - Only messages after this timestamp (integer)
    - `:level` - Only messages with this level ("log", "warn", "error")
    - `:limit` - Maximum number of messages to return (default: 100)

  ## Returns

  List of messages (most recent first), or empty list if none exist.

  ## Examples

      iex> ConsoleCache.get_messages("routine-123", limit: 10)
      [%{level: "log", message: "...", ...}, ...]

      iex> ConsoleCache.get_messages("routine-123", level: "error")
      [%{level: "error", message: "...", ...}]
  """
  @spec get_messages(String.t(), keyword()) :: list(map())
  def get_messages(routine_id, opts \\ []) when is_binary(routine_id) do
    GenServer.call(__MODULE__, {:get_messages, routine_id, opts})
  end

  @doc """
  Clear all messages for a routine.

  Also clears rate limiting data.

  ## Parameters

  - `routine_id` - The routine identifier (string)

  ## Returns

  `:ok`

  ## Examples

      iex> ConsoleCache.clear_messages("routine-123")
      :ok
  """
  @spec clear_messages(String.t()) :: :ok
  def clear_messages(routine_id) when is_binary(routine_id) do
    GenServer.cast(__MODULE__, {:clear_messages, routine_id})
  end

  @doc """
  Clear all messages for all routines.

  Useful for testing or manual cleanup.

  ## Returns

  `:ok`
  """
  @spec clear_all() :: :ok
  def clear_all do
    GenServer.cast(__MODULE__, :clear_all)
  end

  @doc """
  Get statistics about console usage for debugging.

  ## Parameters

  - `routine_id` - The routine identifier (string)

  ## Returns

  Map with statistics:
  - `message_count` - Total messages stored
  - `recent_message_timestamps` - Timestamps of recent messages (for rate limiting)
  - `duplicate_counts` - Map of message hashes to duplicate counts
  - `rate_limit_warnings` - Number of rate limit warnings triggered

  ## Examples

      iex> ConsoleCache.get_stats("routine-123")
      %{message_count: 5, recent_message_timestamps: [...], ...}
  """
  @spec get_stats(String.t()) :: map()
  def get_stats(routine_id) when is_binary(routine_id) do
    GenServer.call(__MODULE__, {:get_stats, routine_id})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    Logger.info("[ConsoleCache] Starting")

    # Start cleanup timer
    :timer.send_interval(@cleanup_interval_ms, self(), :cleanup)

    {:ok, %{}}
  end

  @impl true
  def handle_call({:add_message, routine_id, message}, _from, state) do
    now = System.monotonic_time(:millisecond)
    routine_data = Map.get(state, routine_id, %{messages: [], rate_data: initial_rate_data()})

    case check_rate_limits(routine_data.rate_data, message, now) do
      {:ok, updated_rate_data} ->
        # Add message
        enriched_message = Map.put(message, :cached_at, now)
        new_messages = [enriched_message | routine_data.messages]
        trimmed_messages = Enum.take(new_messages, @max_messages_per_routine)

        new_routine_data = %{
          messages: trimmed_messages,
          rate_data: updated_rate_data
        }

        new_state = Map.put(state, routine_id, new_routine_data)
        {:reply, :ok, new_state}

      {:error, reason, updated_rate_data} ->
        # Store rate limit warning instead
        warning = create_rate_limit_warning(reason, now)
        new_messages = [warning | routine_data.messages]
        trimmed_messages = Enum.take(new_messages, @max_messages_per_routine)

        new_routine_data = %{
          messages: trimmed_messages,
          rate_data: updated_rate_data
        }

        new_state = Map.put(state, routine_id, new_routine_data)
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call({:get_messages, routine_id, opts}, _from, state) do
    routine_data = Map.get(state, routine_id)

    messages =
      case routine_data do
        nil ->
          []

        %{messages: messages} ->
          since = Keyword.get(opts, :since)
          level = Keyword.get(opts, :level)
          limit = Keyword.get(opts, :limit, 100)

          messages
          |> filter_by_timestamp(since)
          |> filter_by_level(level)
          |> Enum.take(limit)

          # Messages are already stored most-recent-first (prepended)
      end

    {:reply, messages, state}
  end

  @impl true
  def handle_call({:get_stats, routine_id}, _from, state) do
    stats =
      case Map.get(state, routine_id) do
        nil ->
          %{
            message_count: 0,
            recent_message_timestamps: [],
            duplicate_counts: %{},
            rate_limit_warnings: 0
          }

        routine_data ->
          rate_data = routine_data.rate_data

          %{
            message_count: length(routine_data.messages),
            recent_message_timestamps: Map.get(rate_data, :recent_timestamps, []),
            duplicate_counts: Map.get(rate_data, :duplicate_counts, %{}),
            rate_limit_warnings: Map.get(rate_data, :rate_limit_count, 0)
          }
      end

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:clear_messages, routine_id}, state) do
    new_state = Map.delete(state, routine_id)
    Logger.debug("[ConsoleCache] Cleared messages for routine #{routine_id}")

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:clear_all, _state) do
    Logger.debug("[ConsoleCache] Cleared all console messages")
    {:noreply, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - @rate_data_ttl_ms

    new_state =
      state
      |> Enum.map(fn {routine_id, routine_data} ->
        # DO NOT clean up messages - they persist for the entire session
        # Only clean up old rate tracking data to prevent memory bloat

        # Clean up old timestamps in rate data
        rate_data = routine_data.rate_data
        recent_timestamps = Map.get(rate_data, :recent_timestamps, [])
        fresh_timestamps = Enum.filter(recent_timestamps, &(&1 > cutoff))

        # Clean up old duplicate tracking data
        duplicate_counts = Map.get(rate_data, :duplicate_counts, %{})

        fresh_duplicate_counts =
          duplicate_counts
          |> Enum.map(fn {hash, timestamps} ->
            {hash, Enum.filter(timestamps, &(&1 > cutoff))}
          end)
          |> Enum.reject(fn {_hash, timestamps} -> Enum.empty?(timestamps) end)
          |> Enum.into(%{})

        updated_rate_data =
          rate_data
          |> Map.put(:recent_timestamps, fresh_timestamps)
          |> Map.put(:duplicate_counts, fresh_duplicate_counts)

        {routine_id, %{messages: routine_data.messages, rate_data: updated_rate_data}}
      end)
      |> Enum.into(%{})

    {:noreply, new_state}
  end

  # Private Helpers

  defp initial_rate_data do
    %{
      recent_timestamps: [],
      duplicate_counts: %{},
      rate_limit_count: 0,
      duplicate_limit_count: 0
    }
  end

  defp check_rate_limits(rate_data, message, now) do
    # Check message rate (messages per second)
    recent_timestamps = Map.get(rate_data, :recent_timestamps, [])
    one_second_ago = now - 1000
    current_second_messages = Enum.count(recent_timestamps, &(&1 > one_second_ago))

    if current_second_messages >= @max_messages_per_second do
      updated_rate_data = Map.update(rate_data, :rate_limit_count, 1, &(&1 + 1))
      {:error, :rate_limit, updated_rate_data}
    else
      # Check for duplicate message spam
      message_hash = hash_message(message)
      duplicate_data = Map.get(rate_data, :duplicate_counts, %{}) |> Map.get(message_hash, [])

      # Only count duplicates within the time window
      time_cutoff = now - @duplicate_time_window_ms
      recent_duplicates = Enum.filter(duplicate_data, &(&1 > time_cutoff))

      if length(recent_duplicates) >= @max_duplicate_messages do
        updated_rate_data = Map.update(rate_data, :duplicate_limit_count, 1, &(&1 + 1))
        {:error, :duplicate_spam, updated_rate_data}
      else
        # Update rate tracking data
        new_timestamps = [now | recent_timestamps] |> Enum.take(20)
        new_duplicate_entry = [now | recent_duplicates] |> Enum.take(@max_duplicate_messages + 1)

        new_duplicate_counts =
          Map.put(rate_data.duplicate_counts || %{}, message_hash, new_duplicate_entry)

        updated_rate_data =
          rate_data
          |> Map.put(:recent_timestamps, new_timestamps)
          |> Map.put(:duplicate_counts, new_duplicate_counts)

        {:ok, updated_rate_data}
      end
    end
  end

  defp create_rate_limit_warning(reason, timestamp) do
    warning_message =
      case reason do
        :rate_limit ->
          "Console rate limit exceeded (max #{@max_messages_per_second}/sec). Some messages suppressed."

        :duplicate_spam ->
          "Duplicate message limit exceeded (max #{@max_duplicate_messages}). Message suppressed."
      end

    %{
      level: "warn",
      message: warning_message,
      timestamp: timestamp,
      cached_at: timestamp,
      system_message: true
    }
  end

  defp hash_message(message) do
    # Create hash of message content to detect duplicates
    content = "#{Map.get(message, :message, "")}#{Map.get(message, :level, "")}"
    :crypto.hash(:md5, content) |> Base.encode16()
  end

  defp filter_by_timestamp(messages, nil), do: messages

  defp filter_by_timestamp(messages, since_timestamp) do
    Enum.filter(messages, fn msg ->
      msg_time = Map.get(msg, :timestamp, 0)
      msg_time > since_timestamp
    end)
  end

  defp filter_by_level(messages, nil), do: messages

  defp filter_by_level(messages, level) when is_binary(level) do
    Enum.filter(messages, fn msg ->
      Map.get(msg, :level) == level
    end)
  end
end
