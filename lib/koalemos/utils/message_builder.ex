defmodule Koalemos.Utils.MessageBuilder do
  @moduledoc """
  Standardized message builder for routine system.

  Provides consistent message formatting for the Anthropic API format
  and handles different content types including text and images.
  """

  @doc """
  Creates a properly formatted user message with text content.

  ## Options

  - `:id` - Unique message ID (defaults to UUID)
  - `:timestamp` - Message timestamp (defaults to now)
  - `:source` - Message source (`:user`, `:system`, `:agent`, etc.)
  - `:routine_id` - Associated routine ID
  """
  def build_user_message(text, opts \\ []) when is_binary(text) do
    %{
      role: "user",
      content: [%{type: "text", text: text}],
      metadata: build_metadata(opts)
    }
  end

  @doc """
  Creates a user message with mixed content (text and/or images).

  ## Examples

      # Text only
      build_user_message_with_content([{:text, "Describe this image"}])

      # Image only
      build_user_message_with_content([{:image, base64_data, "image/jpeg"}])

      # Mixed content
      build_user_message_with_content([
        {:image, base64_data, "image/jpeg"},
        {:text, "What do you see in this image?"}
      ])

  ## Options

  Same options as `build_user_message/2`.
  """
  def build_user_message_with_content(content_parts, opts \\ []) when is_list(content_parts) do
    content = Enum.map(content_parts, &format_content_part/1)

    %{
      role: "user",
      content: content,
      metadata: build_metadata(opts)
    }
  end

  @doc """
  Creates a properly formatted assistant message.

  ## Options

  Same options as `build_user_message/2`.
  """
  def build_assistant_message(content, opts \\ []) when is_list(content) do
    %{
      role: "assistant",
      content: content,
      metadata: build_metadata(opts)
    }
  end

  @doc """
  Creates a tool result message.

  Result content can be:
  - A string: "result text"
  - Content blocks: [{:text, "result"}, {:image, base64, media_type}]

  ## Options

  Same options as `build_user_message/2`, plus:
  - `:is_error` - Boolean indicating if this is an error result
  """
  def build_tool_result_message(tool_id, result_content, opts \\ []) do
    # Format result_content based on type
    formatted_content = case result_content do
      # String result (backward compatible)
      content when is_binary(content) ->
        content

      # Content blocks [{:text, "..."}, {:image, base64, type}]
      content_parts when is_list(content_parts) ->
        Enum.map(content_parts, &format_content_part/1)

      # Unexpected format - convert to string
      content ->
        inspect(content)
    end

    content_block = %{
      type: "tool_result",
      tool_use_id: tool_id,
      content: formatted_content
    }

    content_block = if Keyword.get(opts, :is_error, false) do
      Map.put(content_block, :is_error, true)
    else
      content_block
    end

    %{
      role: "user",
      content: [content_block],
      metadata: build_metadata(opts)
    }
  end

  @doc """
  Validates that a message conforms to the Anthropic API format.
  """
  def validate_message(%{role: role, content: content})
      when role in ["user", "assistant"] and is_list(content) do
    case validate_content(content) do
      :ok -> :ok
      error -> error
    end
  end

  def validate_message(message) do
    {:error, "Invalid message format: #{inspect(message)}"}
  end

  # Private functions

  defp format_content_part({:text, text}) when is_binary(text) do
    %{type: "text", text: text}
  end

  defp format_content_part({:image, base64_data, media_type})
      when is_binary(base64_data) and is_binary(media_type) do
    %{
      type: "image",
      source: %{
        type: "base64",
        media_type: media_type,
        data: base64_data
      }
    }
  end

  defp format_content_part({:image_url, url}) when is_binary(url) do
    %{
      type: "image",
      source: %{
        type: "url",
        url: url
      }
    }
  end

  defp format_content_part(invalid) do
    raise ArgumentError, "Invalid content part: #{inspect(invalid)}"
  end

  defp validate_content(content) when is_list(content) do
    case Enum.all?(content, &valid_content_block?/1) do
      true -> :ok
      false -> {:error, "Invalid content blocks"}
    end
  end

  defp valid_content_block?(%{type: "text", text: text}) when is_binary(text), do: true

  defp valid_content_block?(%{type: "image", source: %{type: "base64", media_type: media_type, data: data}})
      when is_binary(media_type) and is_binary(data) do
    media_type in ["image/jpeg", "image/png", "image/gif", "image/webp"]
  end

  defp valid_content_block?(%{type: "image", source: %{type: "url", url: url}})
      when is_binary(url), do: true

  defp valid_content_block?(%{type: "tool_result", tool_use_id: id, content: content})
      when is_binary(id) and is_binary(content), do: true

  defp valid_content_block?(%{type: "tool_use"}), do: true  # Tool use blocks have complex structure

  defp valid_content_block?(_), do: false

  # Build message metadata with defaults (defensive - always succeed)
  defp build_metadata(opts) do
    try do
      # Base metadata with known fields
      base_metadata = %{
        id: Keyword.get(opts, :id, generate_message_id()),
        timestamp: Keyword.get(opts, :timestamp, iso8601_utc_now()),
        source: Keyword.get(opts, :source, :unknown),
        routine_id: Keyword.get(opts, :routine_id)
      }

      # Merge in any additional metadata keys (like :usage)
      # Base metadata takes precedence over additional keys
      additional_metadata = opts
      |> Keyword.drop([:id, :timestamp, :source, :routine_id])
      |> Enum.into(%{})

      Map.merge(additional_metadata, base_metadata)
    rescue
      _ ->
        # Fallback if anything goes wrong
        %{
          id: "fallback_#{:erlang.phash2(opts)}",
          timestamp: iso8601_utc_now(),
          source: :unknown,
          routine_id: nil
        }
    end
  end

  # Generate ISO 8601 timestamp in UTC (portable and human-readable)
  defp iso8601_utc_now do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  # Generate a unique message ID
  defp generate_message_id do
    "msg_#{:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)}"
  end
end
