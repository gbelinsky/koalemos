defmodule Koalemos.Engine.Observer do
  use GenServer
  require Logger

  @moduledoc """
  Singleton observer for routine events.

  The Observer is a GenServer that receives events from routine execution
  and performs three main functions:

  1. **Event Logging:** Writes events to a file for debugging and auditing
  2. **PubSub Broadcasting:** Broadcasts events to Phoenix PubSub for LiveView updates
  3. **Message Tracking:** Tracks message changes and broadcasts only new messages

  ## Event Flow

      Routine Step → EventRecorder → Observer → PubSub → LiveView
                                          ↓
                                      File Log

  ## PubSub Topics

  - `routine_events` - All events from all routines
  - `routine:<routine_id>` - Events for specific routine
  - `routine:<routine_id>:messages` - New messages only for specific routine

  ## Configuration

  The log file path can be configured in config.exs:

      config :koalemos, :event_log_path, "priv/events.log"

  """

  @log_file_path Application.compile_env(:koalemos, :event_log_path, "priv/events.log")

  @type event :: map()
  @type routine_id :: String.t()
  @type state :: %{last_message_ids: %{optional(routine_id()) => MapSet.t()}}

  ## Client API

  @doc """
  Starts the Observer GenServer.

  This is typically called by the application supervisor.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records an event asynchronously.

  Events are serialized, logged to file, and broadcast to PubSub.

  ## Examples

      Observer.record_event(%{
        routine_id: "abc-123",
        event_type: "step_started",
        metadata: %{step: :init}
      })

  """
  @spec record_event(event()) :: :ok
  def record_event(event) do
    GenServer.cast(__MODULE__, {:record_event, event})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Track last known message IDs per routine for change detection
    {:ok, %{last_message_ids: %{}}}
  end

  @impl true
  def handle_cast({:record_event, event}, state) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    # Convert any tuples to JSON-serializable format
    serializable_event = make_serializable(event)

    # Log to file
    log_entry =
      serializable_event
      |> Map.put(:timestamp, timestamp)
      |> Jason.encode!()

    case File.write(@log_file_path, log_entry <> "\n", [:append]) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to write event log: #{inspect(reason)}")
    end

    # Broadcast to PubSub
    Phoenix.PubSub.broadcast(
      Koalemos.PubSub,
      "routine_events",
      {:routine_event, serializable_event}
    )

    # Also broadcast to routine-specific topic
    if routine_id =
         Map.get(serializable_event, :routine_id) || Map.get(serializable_event, :workflow_id) do
      Phoenix.PubSub.broadcast(
        Koalemos.PubSub,
        "routine:#{routine_id}",
        {:routine_event, serializable_event}
      )
    end

    # Check for message changes and broadcast to message-specific topic
    new_state = check_and_broadcast_message_changes(serializable_event, state)

    {:noreply, new_state}
  end

  ## Serialization

  # Convert DateTime structs to ISO8601 strings
  defp make_serializable(%DateTime{} = dt) do
    DateTime.to_iso8601(dt)
  end

  # Convert maps recursively
  defp make_serializable(data) when is_map(data) do
    Map.new(data, fn {k, v} -> {k, make_serializable(v)} end)
  end

  # Convert lists recursively
  defp make_serializable(data) when is_list(data) do
    Enum.map(data, &make_serializable/1)
  end

  # Convert tuples to lists for JSON serialization
  defp make_serializable(data) when is_tuple(data) do
    data
    |> Tuple.to_list()
    |> make_serializable()
  end

  # Handle functions by converting to string representation
  defp make_serializable(data) when is_function(data) do
    info = Function.info(data)
    arity = Keyword.get(info, :arity, 0)
    module = Keyword.get(info, :module, :unknown)
    name = Keyword.get(info, :name, :anonymous)

    "#Function<#{module}.#{name}/#{arity}>"
  end

  # Handle PIDs
  defp make_serializable(data) when is_pid(data) do
    "#PID<#{inspect(data)}>"
  end

  # Handle references
  defp make_serializable(data) when is_reference(data) do
    "#Ref<#{inspect(data)}>"
  end

  # Handle ports
  defp make_serializable(data) when is_port(data) do
    "#Port<#{inspect(data)}>"
  end

  # Handle booleans and nil - keep as-is for JSON serialization
  defp make_serializable(data) when is_boolean(data) or is_nil(data) do
    data
  end

  # Handle atoms - strip "Elixir." prefix for cleaner output
  defp make_serializable(data) when is_atom(data) do
    case Atom.to_string(data) do
      "Elixir." <> module_name -> module_name
      atom_string -> atom_string
    end
  end

  # Fallback: try encoding, fall back to inspect
  defp make_serializable(data) do
    case Jason.encode(data) do
      {:ok, _} -> data
      {:error, _} -> inspect(data)
    end
  end

  ## Message Change Detection

  # Check for message changes and broadcast only new messages to message-specific topic
  defp check_and_broadcast_message_changes(event, state) do
    case extract_messages_from_event(event) do
      {:ok, routine_id, current_messages} ->
        # Get message IDs from current messages
        current_ids = extract_message_ids(current_messages)
        # Initialize with empty MapSet if first time seeing this routine
        last_ids = Map.get(state.last_message_ids, routine_id, MapSet.new())

        # Find new messages (difference between current and last)
        new_ids = MapSet.difference(current_ids, last_ids)

        if MapSet.size(new_ids) > 0 do
          # Extract only NEW messages to send
          new_messages =
            Enum.filter(current_messages, fn msg ->
              msg_id = get_in(msg, ["metadata", "id"]) || get_in(msg, [:metadata, :id])
              MapSet.member?(new_ids, msg_id)
            end)

          # Broadcast ONLY new messages
          Phoenix.PubSub.broadcast(
            Koalemos.PubSub,
            "routine:#{routine_id}:messages",
            {:new_messages, new_messages}
          )

          # Update tracking
          put_in(state, [:last_message_ids, routine_id], current_ids)
        else
          state
        end

      :no_messages ->
        state
    end
  end

  # Extract message IDs from messages array (defensive - handle messages without metadata)
  defp extract_message_ids(messages) do
    messages
    |> Enum.map(fn msg ->
      # Try to get ID from metadata (both atom and string keys), fallback to generating one from content hash
      case get_in(msg, ["metadata", "id"]) || get_in(msg, [:metadata, :id]) do
        nil ->
          # Old message without metadata - create stable ID from message content
          content_hash = :erlang.phash2(msg)
          "legacy_#{content_hash}"

        id ->
          id
      end
    end)
    |> MapSet.new()
  end

  # Extract messages from routine events (handles both atom and string keys)
  defp extract_messages_from_event(event) do
    # Get event_type (try both atom and string keys)
    event_type = Map.get(event, :event_type) || Map.get(event, "event_type")

    # Look for context_changed events with messages
    if event_type == "context_changed" or event_type == :context_changed do
      routine_id =
        Map.get(event, :routine_id) || Map.get(event, :workflow_id) ||
          Map.get(event, "routine_id") || Map.get(event, "workflow_id")

      context_diff = Map.get(event, :context_diff) || Map.get(event, "context_diff")

      if routine_id && context_diff do
        # Extract messages from diff - handle both append_to and add_or_update operations
        messages = extract_messages_from_diff(context_diff)

        if is_list(messages) and length(messages) > 0 do
          {:ok, routine_id, messages}
        else
          :no_messages
        end
      else
        :no_messages
      end
    else
      :no_messages
    end
  end

  # Extract messages from various diff formats
  defp extract_messages_from_diff(diff) when is_list(diff) do
    # Scan through diff operations looking for messages
    Enum.reduce(diff, [], fn operation, acc ->
      case operation do
        # append_to operation - contains exactly the messages that were added
        [:append_to, appends] when is_map(appends) ->
          new_messages = Map.get(appends, :messages) || Map.get(appends, "messages")

          # Handle both single message and list of messages
          new_messages =
            case new_messages do
              msg when is_map(msg) -> [msg]
              msgs when is_list(msgs) -> msgs
              _ -> []
            end

          acc ++ new_messages

        ["append_to", appends] when is_map(appends) ->
          new_messages = Map.get(appends, :messages) || Map.get(appends, "messages")

          new_messages =
            case new_messages do
              msg when is_map(msg) -> [msg]
              msgs when is_list(msgs) -> msgs
              _ -> []
            end

          acc ++ new_messages

        # add_or_update operation - contains full messages array (fallback for old code)
        [:add_or_update, updates] when is_map(updates) ->
          full_messages = Map.get(updates, :messages) || Map.get(updates, "messages")
          if is_list(full_messages), do: full_messages, else: acc

        ["add_or_update", updates] when is_map(updates) ->
          full_messages = Map.get(updates, :messages) || Map.get(updates, "messages")
          if is_list(full_messages), do: full_messages, else: acc

        _ ->
          acc
      end
    end)
  end

  defp extract_messages_from_diff(_), do: []
end
