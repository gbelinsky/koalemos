defmodule Koalemos.LLMProvider.Utils do
  @moduledoc """
  Common utilities for LLM provider implementations.

  Provides shared functions for message processing that are used
  across multiple provider implementations.
  """

  @doc """
  Strip metadata from a message.

  Messages in the internal format include metadata fields that should
  not be sent to LLM APIs. This function returns a clean message with
  only the API-relevant fields (role and content).

  ## Examples

      iex> msg = %{role: "user", content: "Hi", metadata: %{id: "123"}}
      iex> Koalemos.LLMProvider.Utils.strip_metadata(msg)
      %{role: "user", content: "Hi"}
  """
  def strip_metadata(message) do
    Map.take(message, [:role, :content])
  end

  @doc """
  Filter out empty assistant messages.

  Empty assistant messages (no content, empty array, or nil) should be
  removed before sending to the LLM API. This prevents API errors and
  saves tokens.

  ## Examples

      iex> messages = [
      ...>   %{role: "user", content: [%{type: "text", text: "Hi"}]},
      ...>   %{role: "assistant", content: []},
      ...>   %{role: "user", content: [%{type: "text", text: "Hello?"}]}
      ...> ]
      iex> Koalemos.LLMProvider.Utils.filter_empty_assistant_messages(messages)
      [
        %{role: "user", content: [%{type: "text", text: "Hi"}]},
        %{role: "user", content: [%{type: "text", text: "Hello?"}]}
      ]
  """
  def filter_empty_assistant_messages(messages) do
    Enum.reject(messages, fn msg ->
      msg.role == "assistant" &&
      (msg.content == [] || msg.content == "" || msg.content == nil)
    end)
  end

  @doc """
  Keep only the last screenshot in messages to save tokens.

  Scans through messages and removes all but the most recent screenshot
  (image content blocks). This optimization can save significant tokens
  in long conversations.

  Note: This may be moved to Phase 6d-7 or become obsolete depending
  on how screenshot handling evolves.

  ## Examples

      iex> messages = [
      ...>   %{role: "user", content: [%{type: "image", source: %{data: "old"}}]},
      ...>   %{role: "user", content: [%{type: "text", text: "Hi"}]},
      ...>   %{role: "user", content: [%{type: "image", source: %{data: "new"}}]}
      ...> ]
      iex> result = Koalemos.LLMProvider.Utils.keep_only_last_screenshot(messages)
      iex> Enum.count(result, fn msg ->
      ...>   msg.content
      ...>   |> Enum.any?(fn block -> block[:type] == "image" end)
      ...> end)
      1
  """
  def keep_only_last_screenshot(messages) do
    # Find the index of the last message with a screenshot
    last_screenshot_index = messages
    |> Enum.with_index()
    |> Enum.reverse()
    |> Enum.find_value(fn {msg, idx} ->
      has_screenshot = msg.content
      |> Enum.any?(fn block ->
        Map.get(block, "type") == "image" || Map.get(block, :type) == "image"
      end)

      if has_screenshot, do: idx, else: nil
    end)

    case last_screenshot_index do
      nil ->
        # No screenshots, return as-is
        messages

      last_idx ->
        # Remove screenshots from all messages except the last one
        messages
        |> Enum.with_index()
        |> Enum.map(fn {msg, idx} ->
          if idx == last_idx do
            msg
          else
            # Filter out image blocks
            filtered_content = msg.content
            |> Enum.reject(fn block ->
              Map.get(block, "type") == "image" || Map.get(block, :type) == "image"
            end)

            %{msg | content: filtered_content}
          end
        end)
    end
  end
end
