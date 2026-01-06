defmodule Koalemos.Steps.User.ChatUserInput do
  @moduledoc """
  ChatUserInput step waits for user input events and formats them into messages.

  This step waits for :user_input events from the UI and directly formats them into
  the messages array as proper user messages, avoiding intermediate context pollution.

  ## Supported Input Formats

  - Direct string: "Hello world"
  - Structured: %{user_input: "Hello world"}
  - Pre-formatted: %{messages: [%{role: "user", content: [...]}]}
  - With images: %{text: "Hello", images: [%{base64: "...", media_type: "image/jpeg"}]}
  - Images only: %{images: [...]}

  ## Output

  - Adds formatted user message to messages array
  - Does not pollute context with user_input key
  - Transitions automatically after processing

  ## Example

  ```elixir
  wait_for_user: %{
    type: Koalemos.Steps.User.ChatUserInput,
    transitions: [{:process_input, :always}]
  }
  ```

  The step will wait until the UI sends a :user_input event, then format and append
  the message to context.messages.
  """

  alias Koalemos.Utils.MessageBuilder
  require Logger
  require Koalemos.Log
  alias Koalemos.Log

  @doc """
  Waits for a :user_input event from the UI.

  This blocks until user input is received. The event handler (handle_event/3)
  processes the input and applies the diff internally via Engine.handle_event.
  """
  def execute(_config, state) do
    # Wait for user input event - the event handler applies the diff internally,
    # but we still need to return it so context_changed event gets fired properly
    try do
      _updated_state = Koalemos.Engine.handle_event([:user_input], nil, [], state.routine_id)
      # The diff was already applied by handle_get_event, but we return empty diff
      # because we don't want to double-apply. The message is already in context.
      {:ok, []}
    rescue
      error ->
        Logger.error("Error waiting for user input: #{inspect(error)}")
        {:error, inspect(error)}
    end
  end

  @doc """
  Handles the :user_input event by formatting and appending the message.

  This is called by the Engine when a :user_input event is received while
  execute/2 is waiting.

  If the input includes `include_screenshot: true`, sets the lens_state flag
  so the next lens rendering will capture a screenshot.
  """
  def handle_event(:user_input, data, state) do
    case format_user_input(data, state.routine_id) do
      {:ok, formatted_message} ->
        msg_id = get_in(formatted_message, [:metadata, :id])
        Log.debug(:engine, "[ChatUserInput] User message formatted (id: #{msg_id}), appending")

        # Check if screenshot was requested (only for map input)
        diff =
          if is_map(data) and Map.get(data, :include_screenshot, false) do
            Log.debug(:engine, "[ChatUserInput] Screenshot requested, setting lens_state flag")

            # Merge into existing lens_state to preserve other keys
            existing_lens_state = state.context[:lens_state] || %{}
            updated_lens_state = Map.put(existing_lens_state, :request_screenshot, true)

            [
              append_to: %{messages: [formatted_message]},
              add_or_update: %{lens_state: updated_lens_state}
            ]
          else
            [append_to: %{messages: [formatted_message]}]
          end

        {:ok, diff}

      {:error, reason} ->
        Logger.error("[ChatUserInput] Failed to format user input: #{reason}")
        {:ok, [add: %{error: reason}]}
    end
  end

  # Private formatting functions

  # Direct string input from chat UI
  defp format_user_input(data, routine_id) when is_binary(data) do
    opts = [source: :user, routine_id: routine_id]
    {:ok, MessageBuilder.build_user_message(data, opts)}
  end

  # Wrapped string input
  defp format_user_input(%{user_input: text}, routine_id) when is_binary(text) do
    opts = [source: :user, routine_id: routine_id]
    {:ok, MessageBuilder.build_user_message(text, opts)}
  end

  # Text with images (or text only, or images only)
  defp format_user_input(%{text: text, images: images}, routine_id)
       when is_binary(text) and is_list(images) do
    # Only include text if non-empty (BUG-002 fix)
    text_parts = if text != "", do: [{:text, text}], else: []
    image_parts = Enum.map(images, fn img -> {:image, img.base64, img.media_type} end)
    content_parts = text_parts ++ image_parts

    # If both are empty, this must be a screenshot-only request
    # Create a minimal placeholder message
    content_parts =
      if content_parts == [] do
        [{:text, "(screenshot requested)"}]
      else
        content_parts
      end

    opts = [source: :user, routine_id: routine_id]
    {:ok, MessageBuilder.build_user_message_with_content(content_parts, opts)}
  end

  # Images only (no text)
  defp format_user_input(%{images: images}, routine_id)
       when is_list(images) and length(images) > 0 do
    content_parts = Enum.map(images, fn img -> {:image, img.base64, img.media_type} end)
    opts = [source: :user, routine_id: routine_id]
    {:ok, MessageBuilder.build_user_message_with_content(content_parts, opts)}
  end

  # Pre-formatted message(s) - take first user message
  defp format_user_input(%{messages: msgs}, routine_id) when is_list(msgs) do
    case Enum.find(msgs, fn msg -> msg[:role] == "user" or msg["role"] == "user" end) do
      nil ->
        {:error, "No user message found in pre-formatted input"}

      user_msg ->
        # Extract content (handle both atom and string keys)
        content = Map.get(user_msg, :content) || Map.get(user_msg, "content")

        # Rebuild message with proper metadata
        rebuilt_msg =
          if is_list(content) do
            # Normalize content blocks to use atom keys for validation
            normalized_content = Enum.map(content, &normalize_content_block/1)

            %{
              role: "user",
              content: normalized_content,
              metadata: MessageBuilder.build_user_message("", routine_id: routine_id).metadata
            }
          else
            # Fallback for unexpected format
            MessageBuilder.build_user_message(inspect(content), routine_id: routine_id)
          end

        case MessageBuilder.validate_message(rebuilt_msg) do
          :ok -> {:ok, rebuilt_msg}
          error -> error
        end
    end
  end

  # Unsupported format
  defp format_user_input(data, _routine_id) do
    {:error, "Unsupported user input format: #{inspect(data)}"}
  end

  # Normalize content block keys from strings to atoms
  # NOTE: String.to_existing_atom can crash on unknown keys. This is low risk because:
  # 1. Only affects pre-formatted messages (edge case)
  # 2. Known content block keys (type, text, source, etc.) already exist as atoms
  # 3. If this becomes a problem, add a whitelist of known keys or use try/rescue
  defp normalize_content_block(%{"type" => _type} = block) do
    # Convert string keys to atom keys
    Enum.reduce(block, %{}, fn {key, value}, acc ->
      atom_key = if is_binary(key), do: String.to_existing_atom(key), else: key
      Map.put(acc, atom_key, normalize_value(value))
    end)
  end

  defp normalize_content_block(block) when is_map(block) do
    # Already has atom keys or mixed, normalize recursively
    Enum.reduce(block, %{}, fn {key, value}, acc ->
      Map.put(acc, key, normalize_value(value))
    end)
  end

  # Recursively normalize nested maps
  defp normalize_value(%{"type" => _} = map), do: normalize_content_block(map)

  defp normalize_value(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      atom_key = if is_binary(key), do: String.to_existing_atom(key), else: key
      Map.put(acc, atom_key, normalize_value(value))
    end)
  end

  defp normalize_value(value), do: value
end
