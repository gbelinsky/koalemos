defmodule Koalemos.Engine.EventBuffer do
  @moduledoc """
  Event buffer for storing and retrieving routine events by type.

  Events are organized by type for efficient lookup, with each type
  maintaining a list of events in insertion order (FIFO).

  ## Known Limitation: Unbounded Growth

  The buffer currently has no size limit. In normal operation this is fine
  because events are consumed as they arrive. However, if events accumulate
  faster than they're consumed, memory could grow unbounded. For production
  use, consider adding: max buffer size, per-type limits, or TTL-based expiry.

  ## Usage

  The EventBuffer is used to store external events that arrive while
  a routine is executing. Steps can wait for specific event types,
  and the buffer will be searched for matching events.

  ## Example

      # Create a new buffer
      buffer = EventBuffer.new()

      # Add events
      buffer = EventBuffer.add(buffer, :user_input, %{text: "hello"})
      buffer = EventBuffer.add(buffer, :webhook, %{data: "payload"})
      buffer = EventBuffer.add(buffer, :user_input, %{text: "world"})

      # Find and remove first matching event
      case EventBuffer.find_and_remove(buffer, [:user_input, :timer]) do
        {:found, :user_input, data, timestamp, new_buffer} ->
          # Process the user input
          IO.inspect(data)  # %{text: "hello"}
          new_buffer

        :not_found ->
          # No matching events
          buffer
      end

  ## FIFO Ordering

  Events of the same type are returned in FIFO (first-in, first-out) order:

      buffer = EventBuffer.new()
      buffer = EventBuffer.add(buffer, :msg, "first")
      buffer = EventBuffer.add(buffer, :msg, "second")

      {:found, :msg, "first", _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      {:found, :msg, "second", _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      :not_found = EventBuffer.find_and_remove(buffer, [:msg])

  """

  @type event_type :: atom()
  @type event_data :: any()
  @type timestamp :: integer()
  @type event :: {event_data(), timestamp()}
  @type t :: %{optional(event_type()) => [event()]}

  @doc """
  Creates a new empty event buffer.

  ## Examples

      iex> EventBuffer.new()
      %{}

      iex> EventBuffer.new() |> EventBuffer.empty?()
      true

  """
  @spec new() :: t()
  def new do
    %{}
  end

  @doc """
  Adds an event to the buffer.

  Events are appended to the end of the list for their type,
  maintaining FIFO ordering.

  ## Parameters

  - `buffer` - The current event buffer
  - `event_type` - The type of event (e.g., `:user_input`, `:webhook`)
  - `data` - The event data payload
  - `timestamp` - Optional timestamp (defaults to current system time in milliseconds)

  ## Examples

      iex> buffer = EventBuffer.new()
      iex> buffer = EventBuffer.add(buffer, :user_input, "hello")
      iex> EventBuffer.size(buffer, :user_input)
      1

      iex> buffer = EventBuffer.new()
      iex> buffer = EventBuffer.add(buffer, :msg, "first")
      iex> buffer = EventBuffer.add(buffer, :msg, "second")
      iex> EventBuffer.size(buffer, :msg)
      2

  """
  @spec add(t(), event_type(), event_data(), timestamp() | nil) :: t()
  def add(buffer, event_type, data, timestamp \\ nil) do
    timestamp = timestamp || System.system_time(:millisecond)
    event = {data, timestamp}

    Map.update(buffer, event_type, [event], fn existing_events ->
      existing_events ++ [event]
    end)
  end

  @doc """
  Finds and removes the first matching event for any of the given event types.

  Searches through the event types in order, returning the first event found.
  The event is removed from the buffer.

  ## Parameters

  - `buffer` - The current event buffer
  - `event_types` - List of event types to search for (checked in order)

  ## Returns

  - `{:found, event_type, data, timestamp, updated_buffer}` if an event is found
  - `:not_found` if no matching events exist

  ## Examples

      iex> buffer = EventBuffer.new()
      iex> buffer = EventBuffer.add(buffer, :user_input, "hello", 1000)
      iex> {:found, :user_input, "hello", 1000, new_buffer} =
      ...>   EventBuffer.find_and_remove(buffer, [:user_input])
      iex> EventBuffer.empty?(new_buffer)
      true

      iex> buffer = EventBuffer.new()
      iex> EventBuffer.find_and_remove(buffer, [:user_input])
      :not_found

      iex> buffer = EventBuffer.new()
      iex> buffer = EventBuffer.add(buffer, :webhook, "data")
      iex> {:found, :webhook, "data", _ts, _buffer} =
      ...>   EventBuffer.find_and_remove(buffer, [:user_input, :webhook])

  """
  @spec find_and_remove(t(), [event_type()]) ::
          {:found, event_type(), event_data(), timestamp(), t()} | :not_found
  def find_and_remove(buffer, event_types) do
    Enum.find_value(event_types, fn event_type ->
      case Map.get(buffer, event_type, []) do
        [] ->
          nil

        [{data, timestamp} | rest] ->
          updated_buffer =
            case rest do
              [] -> Map.delete(buffer, event_type)
              _ -> Map.put(buffer, event_type, rest)
            end

          {:found, event_type, data, timestamp, updated_buffer}
      end
    end) || :not_found
  end

  @doc """
  Returns the total number of events in the buffer across all types.

  ## Examples

      iex> buffer = EventBuffer.new()
      iex> buffer = EventBuffer.add(buffer, :user_input, "hello")
      iex> buffer = EventBuffer.add(buffer, :webhook, "data")
      iex> EventBuffer.size(buffer)
      2

      iex> EventBuffer.new() |> EventBuffer.size()
      0

  """
  @spec size(t()) :: non_neg_integer()
  def size(buffer) do
    buffer
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  @doc """
  Returns the number of events for a specific event type.

  ## Examples

      iex> buffer = EventBuffer.new()
      iex> buffer = EventBuffer.add(buffer, :user_input, "one")
      iex> buffer = EventBuffer.add(buffer, :user_input, "two")
      iex> EventBuffer.size(buffer, :user_input)
      2

      iex> buffer = EventBuffer.new()
      iex> EventBuffer.size(buffer, :missing)
      0

  """
  @spec size(t(), event_type()) :: non_neg_integer()
  def size(buffer, event_type) do
    buffer
    |> Map.get(event_type, [])
    |> length()
  end

  @doc """
  Returns all event types that have buffered events.

  ## Examples

      iex> buffer = EventBuffer.new()
      iex> buffer = EventBuffer.add(buffer, :user_input, "data")
      iex> buffer = EventBuffer.add(buffer, :webhook, "data")
      iex> types = EventBuffer.event_types(buffer)
      iex> Enum.sort(types)
      [:user_input, :webhook]

      iex> EventBuffer.new() |> EventBuffer.event_types()
      []

  """
  @spec event_types(t()) :: [event_type()]
  def event_types(buffer) do
    Map.keys(buffer)
  end

  @doc """
  Removes events older than the specified age in milliseconds.

  Useful for preventing unbounded buffer growth by periodically
  cleaning up old events that are no longer relevant.

  ## Parameters

  - `buffer` - The current event buffer
  - `max_age_ms` - Maximum age in milliseconds

  ## Examples

      iex> now = System.system_time(:millisecond)
      iex> buffer = EventBuffer.new()
      iex> buffer = EventBuffer.add(buffer, :old, "data", now - 10000)
      iex> buffer = EventBuffer.add(buffer, :recent, "data", now - 100)
      iex> buffer = EventBuffer.cleanup_old_events(buffer, 5000)
      iex> EventBuffer.size(buffer, :old)
      0
      iex> EventBuffer.size(buffer, :recent)
      1

  """
  @spec cleanup_old_events(t(), non_neg_integer()) :: t()
  def cleanup_old_events(buffer, max_age_ms) do
    cutoff_time = System.system_time(:millisecond) - max_age_ms

    buffer
    |> Enum.map(fn {event_type, events} ->
      recent_events =
        Enum.filter(events, fn {_data, timestamp} ->
          timestamp >= cutoff_time
        end)

      {event_type, recent_events}
    end)
    |> Enum.reject(fn {_event_type, events} -> events == [] end)
    |> Map.new()
  end

  @doc """
  Returns true if the buffer is empty (no events of any type).

  ## Examples

      iex> EventBuffer.new() |> EventBuffer.empty?()
      true

      iex> buffer = EventBuffer.new()
      iex> buffer = EventBuffer.add(buffer, :user_input, "data")
      iex> EventBuffer.empty?(buffer)
      false

      iex> buffer = EventBuffer.new()
      iex> buffer = EventBuffer.add(buffer, :msg, "data")
      iex> {:found, _, _, _, buffer} = EventBuffer.find_and_remove(buffer, [:msg])
      iex> EventBuffer.empty?(buffer)
      true

  """
  @spec empty?(t()) :: boolean()
  def empty?(buffer) do
    Map.values(buffer) |> Enum.all?(&(&1 == []))
  end
end
