defmodule KoalemosWeb.MessageCards.Helpers do
  @moduledoc """
  Shared utility functions for message card components.
  """

  @doc """
  Generates a unique card ID from a message's timestamp.
  """
  def generate_card_id(message) do
    case get_in(message, [:metadata, :timestamp]) do
      ts when is_binary(ts) -> "card_#{:erlang.phash2(ts)}"
      ts when is_integer(ts) -> "card_#{ts}"
      %DateTime{} = ts -> "card_#{DateTime.to_unix(ts, :microsecond)}"
      _ -> "card_#{:erlang.phash2(message)}"
    end
  end

  @doc """
  Extracts text content from a message's content field.
  Handles both string content and structured content arrays.
  """
  def extract_text_content(content) do
    cond do
      is_binary(content) ->
        content

      is_list(content) ->
        # Check if this is a tool result list
        tool_result =
          Enum.find(content, fn item ->
            Map.get(item, :type) == "tool_result" || Map.get(item, "type") == "tool_result"
          end)

        if tool_result do
          # Extract content from tool result
          Map.get(tool_result, :content) || Map.get(tool_result, "content") ||
            "No content in tool result"
        else
          # Regular text content extraction
          content
          |> Enum.filter(fn item ->
            Map.get(item, :type) == "text" || Map.get(item, "type") == "text"
          end)
          |> Enum.map(fn item -> Map.get(item, :text) || Map.get(item, "text") || "" end)
          |> Enum.join(" ")
          |> String.trim()
        end

      true ->
        inspect(content)
    end
  end

  @doc """
  Extracts text and images from a message's content field.
  Returns {text_content, image_items}.
  """
  def extract_text_and_images(content) do
    cond do
      is_list(content) ->
        text_items =
          Enum.filter(content, fn item ->
            Map.get(item, :type) == "text" || Map.get(item, "type") == "text"
          end)

        image_items =
          Enum.filter(content, fn item ->
            Map.get(item, :type) == "image" || Map.get(item, "type") == "image"
          end)

        text_content =
          text_items
          |> Enum.map(fn item -> Map.get(item, :text) || Map.get(item, "text") || "" end)
          |> Enum.join(" ")
          |> String.trim()

        {text_content, image_items}

      is_binary(content) ->
        text_content =
          content
          |> String.replace(~r/\s*\[with \d+ image\(s\)\]/, "")
          |> String.trim()

        {text_content, []}

      true ->
        {"", []}
    end
  end

  @doc """
  Checks if a message has images in its content.
  """
  def has_images?(message) do
    content = message.content

    cond do
      # Check if content is a list containing image objects
      is_list(content) ->
        Enum.any?(content, fn item ->
          Map.get(item, :type) == "image" || Map.get(item, "type") == "image"
        end)

      # Fallback: Check for old text patterns like "[with 2 image(s)]"
      is_binary(content) && String.contains?(content, "[with") &&
          String.contains?(content, "image") ->
        true

      true ->
        false
    end
  end
end
